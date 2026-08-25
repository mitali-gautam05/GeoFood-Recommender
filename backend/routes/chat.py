# backend/routes/chat.py
"""
Phase 2 routes: /api/v1/chat (full parse -> retrieve -> rerank -> explain
pipeline) and /api/v1/explain (on-demand single-restaurant explanation,
e.g. Flutter's "why this?" tap on one card, instead of paying the LLM
cost for every card up front on every search).

Registered the same way as routes/recommender.py -- see main.py.
"""

from fastapi import APIRouter, HTTPException, Depends
from pydantic import BaseModel
from sqlalchemy.orm import Session

from database import get_db
from routes.recommender import RecommendRequest  # reuse -- identical fields to /recommend
from services.chat_orchestrator import chat_recommend
from services.llm_engine import explain_recommendations

router = APIRouter()


class ExplainRequest(BaseModel):
    query: str
    name: str
    cuisine: str
    rating: float
    price: float
    why_recommended: str


@router.post("/chat")
async def chat(
    req: RecommendRequest,
    db: Session = Depends(get_db),
):
    try:
        result = await chat_recommend(
            username=req.username,
            query=req.query,
            city=req.city,
            budget=req.budget,
            min_rating=req.min_rating,
            top_n=req.top_n,
            hunger_mode=req.hunger_mode,
            user_lat=req.user_lat,
            user_lng=req.user_lng,
            mood=req.mood,
            time_slot=req.time_slot,
            weather_tags=req.weather_tags,
            avoid_cuisines=req.avoid_cuisines,
            db=db,
        )
        return result
    except Exception as e:
        import traceback
        traceback.print_exc()
        raise HTTPException(status_code=500, detail=str(e))


@router.post("/explain")
async def explain_one(req: ExplainRequest):
    """
    On-demand explanation for a single restaurant. Cheaper than
    explaining every card in a result list up front -- only called when
    the user actually wants to know "why this?" for one specific place.
    """
    try:
        restaurant = {
            "name": req.name,
            "cuisine": req.cuisine,
            "rating": req.rating,
            "price": req.price,
            "why_recommended": req.why_recommended,
        }
        explanations = await explain_recommendations(req.query, [restaurant])
        explanation = explanations.get(req.name)

        return {
            "name": req.name,
            "llm_explanation": explanation,       # None if generation failed or was dropped by the grounding check
            "fallback_reason": req.why_recommended,  # always available -- guaranteed non-empty
        }
    except Exception as e:
        import traceback
        traceback.print_exc()
        raise HTTPException(status_code=500, detail=str(e))