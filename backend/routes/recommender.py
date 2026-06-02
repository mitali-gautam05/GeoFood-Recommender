# backend/routes/recommender.py
# Changes from original:
#   1. RecommendRequest now accepts mood, time_slot, weather_tags, avoid_cuisines
#   2. All endpoints now receive a DB session via Depends(get_db)
#   3. /click persists to PostgreSQL (not just RAM)
#   4. recommend() call passes db session for cache + click history

from fastapi import APIRouter, HTTPException, Depends
from pydantic import BaseModel
from typing import Optional, List
from sqlalchemy.orm import Session

from database import get_db
from services.recommender import (
    recommend,
    record_click,
    set_not_hungry,
    is_paused,
    get_available_cities,
    search_cities,
    df,
)

router = APIRouter()


class RecommendRequest(BaseModel):
    username:    str
    query:       str
    city:        str
    budget:      float = 300
    min_rating:  float = 3.5
    top_n:       int   = 5
    hunger_mode: str   = "hungry"
    user_lat:    Optional[float] = None
    user_lng:    Optional[float] = None
    # NEW — Flutter already sends these, now the backend accepts them
    mood:            Optional[str]       = None
    time_slot:       Optional[str]       = None
    weather_tags:    Optional[List[str]] = None
    avoid_cuisines:  Optional[List[str]] = None


class ClickRequest(BaseModel):
    username:  str
    food_type: str
    city:      Optional[str] = None   # NEW — store city context with click


@router.post("/recommend")
def get_recommendations(
    req: RecommendRequest,
    db:  Session = Depends(get_db),   # ← DB session injected
):
    try:
        result = recommend(
            username       = req.username,
            query          = req.query,
            city           = req.city,
            budget         = req.budget,
            min_rating     = req.min_rating,
            top_n          = req.top_n,
            hunger_mode    = req.hunger_mode,
            user_lat       = req.user_lat,
            user_lng       = req.user_lng,
            # NEW signals passed through
            mood           = req.mood,
            time_slot      = req.time_slot,
            weather_tags   = req.weather_tags,
            avoid_cuisines = req.avoid_cuisines,
            db             = db,      # ← enables cache + PostgreSQL click history
        )
        return {
            "status":            result["status"],
            "searched_city":     result.get("searched_city", req.city),
            "matched_city":      result.get("matched_city", ""),
            "suggestions":       result.get("suggestions", []),
            "fallback_from":     result.get("fallback_from"),
            "fallback_distance": result.get("fallback_distance"),
            "paused":            is_paused(req.username),
            "recommendations":   result.get("recommendations", []),
        }
    except Exception as e:
        import traceback
        traceback.print_exc()
        raise HTTPException(status_code=500, detail=str(e))


@router.post("/click")
def log_click(
    req: ClickRequest,
    db:  Session = Depends(get_db),   # ← persists to PostgreSQL
):
    record_click(req.username, req.food_type, city=req.city, db=db)
    return {"status": "recorded"}


@router.post("/not-hungry")
def not_hungry(req: ClickRequest):
    set_not_hungry(req.username)
    return {"status": "paused", "minutes": 60}


@router.get("/cities")
def get_cities():
    return {"cities": get_available_cities()}


@router.get("/cities/search")
def search_city(q: str = ""):
    return {"cities": search_cities(q, limit=8)}


@router.get("/health")
def health():
    return {"status": "ok", "restaurants_loaded": len(df)}