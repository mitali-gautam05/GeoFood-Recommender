"""
services/chat_orchestrator.py

Async orchestrator for Phase 2's combined flow:
    parse (LLM) -> retrieve + rerank (existing recommend()) -> explain (LLM)

recommend() itself stays synchronous (it's pandas/ChromaDB work) -- the
only actual async I/O is the two Groq calls, which happen here, before
and after calling into the existing recommender untouched.
"""

import logging
from services.recommender import recommend
from services.llm_engine import parse_query, explain_recommendations

logger = logging.getLogger(__name__)


async def chat_recommend(
    username: str,
    query: str,
    city: str,
    budget: float = 300,
    min_rating: float = 3.5,
    top_n: int = 5,
    hunger_mode: str = "hungry",
    hour: int = None,
    user_lat: float = None,
    user_lng: float = None,
    mood: str = None,
    time_slot: str = None,
    weather_tags: list = None,
    avoid_cuisines: list = None,
    db=None,
) -> dict:
    """
    Full Phase 2 pipeline: parse the raw query into structured filters,
    run the existing hybrid recommender with those filters, then
    generate grounded LLM explanations for the results.

    Fails soft at every LLM step -- if parsing fails, falls back to the
    raw query untouched (TF-IDF + semantic search still work fine with
    no extra filters). If explanation generation fails or an explanation
    gets dropped by the grounding check, the rule-based `why_recommended`
    field is always still present on every result -- the user never sees
    a broken response, worst case they see the simpler rule-based reason.
    """
    parsed = await parse_query(query)

    cleaned_query = parsed.get("cleaned_query") or query
    parsed_budget_max = parsed.get("budget_max")
    parsed_cuisine = parsed.get("cuisine")

    # If the LLM extracted an explicit budget ceiling, use it for BOTH the
    # hard ChromaDB filter AND the existing Gaussian budget_score fit --
    # keeps the hard filter and the soft scoring signal consistent with
    # each other instead of silently disagreeing.
    effective_budget = parsed_budget_max if parsed_budget_max is not None else budget

    result = recommend(
        username=username,
        query=cleaned_query,
        city=city,
        budget=effective_budget,
        min_rating=min_rating,
        top_n=top_n,
        hunger_mode=hunger_mode,
        hour=hour,
        user_lat=user_lat,
        user_lng=user_lng,
        mood=mood,
        time_slot=time_slot,
        weather_tags=weather_tags,
        avoid_cuisines=avoid_cuisines,
        budget_max=parsed_budget_max,
        cuisine=parsed_cuisine,
        db=db,
    )

    result["parsed_filters"] = parsed  # transparency: what the LLM extracted from the query

    if result["status"] != "ok" or not result["recommendations"]:
        return result

    llm_explanations = await explain_recommendations(query, result["recommendations"])

    for item in result["recommendations"]:
        item["llm_explanation"] = llm_explanations.get(item["name"])  # None if not generated or dropped

    return result