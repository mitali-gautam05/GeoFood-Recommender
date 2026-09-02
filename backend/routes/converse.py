# backend/routes/converse.py
"""
Phase 3 route: /api/v1/converse -- the stateful, agentic version of
/api/v1/chat. Uses the LangGraph flow (router -> parse -> retrieve ->
retry-if-empty -> explain -> finalize) instead of the straight-line
Phase 2 pipeline, so it supports follow-ups via Redis session history.

/api/v1/chat (Phase 2) is left as-is for stateless, single-shot use.
"""

from fastapi import APIRouter, HTTPException, Depends
from sqlalchemy.orm import Session

from database import get_db
from routes.recommender import RecommendRequest  # same fields, reused
from services.chat_graph import run_chat_graph

router = APIRouter()


@router.post("/converse")
async def converse(
    req: RecommendRequest,
    db: Session = Depends(get_db),
):
    try:
        result = await run_chat_graph(
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