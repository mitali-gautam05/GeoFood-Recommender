"""
services/chat_graph.py

Phase 3: LangGraph state machine for the conversational flow.

    START -> router -> parse -> retrieve -> [conditional]
                                    |              |
                              (empty results,   (has results,
                               retries < 1)      or out of retries)
                                    |              |
                                    v              v
                               bump_retry      explain -> finalize -> END
                                    |
                                    +--> back to retrieve (widened filters)

Unlike Phase 2's chat_orchestrator.py (a straight-line pipeline), this
adds real state (conversation history via session_store) and a genuine
try/evaluate/retry loop -- not just Phase 2's internal budget relaxation
(which lives inside get_semantic_scores and still runs here too, this
loop sits one level above it).
"""

import logging
from typing import Optional, TypedDict
from langgraph.graph import StateGraph, START, END

from services.recommender import recommend , record_click
from services.llm_engine import parse_query, resolve_followup, explain_recommendations
from services.session_store import get_session_history, append_turn

logger = logging.getLogger(__name__)


class ChatState(TypedDict, total=False):
    username: str
    query: str
    city: str
    budget: float
    min_rating: float
    top_n: int
    hunger_mode: str
    user_lat: Optional[float]
    user_lng: Optional[float]
    mood: Optional[str]
    time_slot: Optional[str]
    weather_tags: Optional[list]
    avoid_cuisines: Optional[list]
    db: object
    resolved_query: str
    is_followup: bool
    parsed_filters: dict
    retry_count: int
    intent: str
    clicked_name: Optional[str]
    result: dict


async def router_node(state: ChatState) -> dict:
    """Reads conversation history and resolves whether this is a
    follow-up, carrying forward city/context if so. Also classifies
    intent (search vs. a click/selection on a previously shown
    restaurant) so the graph can route around parse/retrieve/explain
    entirely for a click -- zero extra LLM calls, this reuses the same
    resolve_followup() call that already ran for follow-up detection."""
    history = get_session_history(state["username"])
    followup = await resolve_followup(history, state["query"])
    return {
        "resolved_query": followup["resolved_query"],
        "is_followup": followup["is_followup"],
        "city": followup.get("city") or state["city"],
        "intent": followup.get("intent", "search"),
        "clicked_name": followup.get("clicked_name"),
    }


def click_node(state: ChatState) -> dict:
    """
    Handles a click/selection follow-up (e.g. "the first one, love it")
    without going through parse/retrieve/explain -- reuses the existing
    PostgreSQL-backed record_click() (same function routes/recommender.py's
    /click endpoint calls), just invoked directly instead of a second
    HTTP round-trip.

    record_click() tracks by cuisine/food_type, not restaurant name, so
    clicked_name (from resolve_followup) is resolved against the
    *previous* turn's stored results to find the matching cuisine --
    the cuisine itself is never trusted from the LLM, only looked up
    from data we already grounded in the prior recommend() call.
    Fails soft: if no match is found (stale reference or a name the
    model didn't actually see), returns a message instead of guessing.
    """
    clicked_name = state.get("clicked_name")
    history = get_session_history(state["username"])
    cuisine = None
    matched_name = None
    for turn in reversed(history):
        for r in turn.get("results", []):
            if r.get("name") == clicked_name:
                cuisine = r.get("cuisine")
                matched_name = r.get("name")
                break
        if cuisine:
            break

    if not cuisine:
        result = {
            "status": "click_unresolved",
            "message": "Couldn't match that to a restaurant from the last results -- could you name it directly?",
        }
    else:
        record_click(state["username"], cuisine, city=state.get("city"), db=state.get("db"))
        result = {
            "status": "click_recorded",
            "clicked_name": matched_name,
            "cuisine": cuisine,
        }

    append_turn(state["username"], {
        "query": state["query"],
        "resolved_query": state["resolved_query"],
        "city": state["city"],
        "results": [],  # a click turn doesn't produce new recommendations
    })
    result["is_followup"] = state.get("is_followup", False)
    return {"result": result}


async def parse_node(state: ChatState) -> dict:
    parsed = await parse_query(state["resolved_query"])
    return {"parsed_filters": parsed}


def retrieve_node(state: ChatState) -> dict:
    """
    Calls the existing (sync) recommend() -- Phase 1/2 hybrid retrieval,
    scoring, and Phase 2's internal budget relaxation all run here
    unchanged. On a graph-level retry (retry_count >= 1), widens the net
    further: drops the cuisine soft-boost and eases the rating floor --
    a level of relaxation Phase 2 doesn't do on its own.
    """
    parsed = state.get("parsed_filters", {}) or {}
    cleaned_query = parsed.get("cleaned_query") or state["resolved_query"]
    budget_max = parsed.get("budget_max")
    cuisine = parsed.get("cuisine")
    retry_count = state.get("retry_count", 0)

    min_rating = state["min_rating"]
    if retry_count >= 1:
        cuisine = None
        min_rating = max(3.0, min_rating - 0.5)

    effective_budget = budget_max if budget_max is not None else state["budget"]

    result = recommend(
        username=state["username"],
        query=cleaned_query,
        city=state["city"],
        budget=effective_budget,
        min_rating=min_rating,
        top_n=state["top_n"],
        hunger_mode=state.get("hunger_mode", "hungry"),
        user_lat=state.get("user_lat"),
        user_lng=state.get("user_lng"),
        mood=state.get("mood"),
        time_slot=state.get("time_slot"),
        weather_tags=state.get("weather_tags"),
        avoid_cuisines=state.get("avoid_cuisines"),
        budget_max=budget_max,
        cuisine=cuisine,
        db=state.get("db"),
    )
    result["parsed_filters"] = parsed
    return {"result": result}


def should_retry(state: ChatState) -> str:
    result = state.get("result", {})
    has_results = bool(result.get("recommendations"))
    retry_count = state.get("retry_count", 0)
    if not has_results and retry_count < 1:
        return "retry"
    return "continue"


def bump_retry_node(state: ChatState) -> dict:
    return {"retry_count": state.get("retry_count", 0) + 1}


async def explain_node(state: ChatState) -> dict:
    result = state["result"]
    if result.get("status") != "ok" or not result.get("recommendations"):
        return {"result": result}

    explanations = await explain_recommendations(state["resolved_query"], result["recommendations"])
    for item in result["recommendations"]:
        item["llm_explanation"] = explanations.get(item["name"])
    return {"result": result}


def finalize_node(state: ChatState) -> dict:
    """Persists this turn to session history and stamps whether it was
    treated as a follow-up, then returns the final result. Also stores
    each recommended restaurant's name + cuisine in the turn -- this is
    what click_node looks up on a later "the first one" style turn."""
    result = state["result"]
    recs = result.get("recommendations", []) if isinstance(result, dict) else []
    append_turn(state["username"], {
        "query": state["query"],
        "resolved_query": state["resolved_query"],
        "city": state["city"],
        "results": [
            {"name": r.get("name"), "cuisine": r.get("cuisine")}
            for r in recs
        ],
    })
    result["is_followup"] = state.get("is_followup", False)
    return {"result": result}


def build_chat_graph():
    graph = StateGraph(ChatState)
    graph.add_node("router", router_node)
    graph.add_node("click", click_node)
    graph.add_node("parse", parse_node)
    graph.add_node("retrieve", retrieve_node)
    graph.add_node("bump_retry", bump_retry_node)
    graph.add_node("explain", explain_node)
    graph.add_node("finalize", finalize_node)

    graph.add_edge(START, "router")
    graph.add_conditional_edges(
        "router",
        lambda state: "click" if state.get("intent") == "click" else "parse",
        {"click": "click", "parse": "parse"},
    )
    graph.add_edge("click", END)
    graph.add_edge("parse", "retrieve")
    graph.add_conditional_edges("retrieve", should_retry, {"retry": "bump_retry", "continue": "explain"})
    graph.add_edge("bump_retry", "retrieve")
    graph.add_edge("explain", "finalize")
    graph.add_edge("finalize", END)

    return graph.compile()


chat_graph = build_chat_graph()


async def run_chat_graph(
    username: str,
    query: str,
    city: str,
    budget: float = 300,
    min_rating: float = 3.5,
    top_n: int = 5,
    hunger_mode: str = "hungry",
    user_lat: Optional[float] = None,
    user_lng: Optional[float] = None,
    mood: Optional[str] = None,
    time_slot: Optional[str] = None,
    weather_tags: Optional[list] = None,
    avoid_cuisines: Optional[list] = None,
    db=None,
) -> dict:
    """Entry point for the /api/v1/converse route."""
    initial_state: ChatState = {
        "username": username,
        "query": query,
        "city": city,
        "budget": budget,
        "min_rating": min_rating,
        "top_n": top_n,
        "hunger_mode": hunger_mode,
        "user_lat": user_lat,
        "user_lng": user_lng,
        "mood": mood,
        "time_slot": time_slot,
        "weather_tags": weather_tags,
        "avoid_cuisines": avoid_cuisines,
        "db": db,
        "retry_count": 0,
    }
    final_state = await chat_graph.ainvoke(initial_state)
    return final_state["result"]