from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session
from datetime import datetime

from database import get_db
from routes.auth import get_current_user
from models.place import Place
from services.geo_service import fetch_from_osm, haversine
from services.recommendation_service import rank_places

router = APIRouter(prefix="/places", tags=["Places"])


@router.get("/nearby")
async def get_nearby_places(
    lat: float,
    lon: float,
    radius: int = 1000,
    db: Session = Depends(get_db),
    user=Depends(get_current_user)
):
    places = db.query(Place).all()
    nearby = []

    for place in places:
        dist = haversine(lat, lon, place.lat, place.lon)

        if dist <= radius / 1000:
            place.distance_km = round(dist, 2)
            nearby.append(place)

    if len(nearby) >= 5:
        nearby.sort(key=lambda x: x.distance_km)

        return {
            "source": "database",
            "count": len(nearby),
            "places": [
                {
                    "name": p.name,
                    "type": p.type,
                    "distance_km": p.distance_km
                } for p in nearby
            ]
        }

    osm_places = await fetch_from_osm(lat, lon, radius)

    for item in osm_places:
        tags = item.get("tags", {})
        name = tags.get("name")

        if not name:
            continue

        osm_id = str(item["id"])

        exists = db.query(Place).filter(Place.osm_id == osm_id).first()

        if not exists:
            db.add(
                Place(
                    osm_id=osm_id,
                    name=name,
                    lat=item["lat"],
                    lon=item["lon"],
                    type=tags.get("amenity", "unknown"),
                    cuisine=tags.get("cuisine", "unknown"),
                    rating=4.0,
                    fetched_at=datetime.utcnow()
                )
            )

    db.commit()

    return await get_nearby_places(lat, lon, radius, db, user)


@router.get("/recommend")
async def recommend_places(
    lat: float,
    lon: float,
    radius: int = 3000,
    preference: str = None,
    db: Session = Depends(get_db),
):
    places = db.query(Place).all()

    nearby = []

    for place in places:
        dist = haversine(lat, lon, place.lat, place.lon)

        if dist <= radius / 1000:
            place.distance_km = round(dist, 2)
            nearby.append(place)

    ranked = rank_places(nearby, preference)

    return {
        "success": True,
        "count": len(ranked),
        "results": [
            {
                "name": p.name,
                "type": p.type,
                "distance_km": p.distance_km,
                "score": p.score
            }
            for p in ranked
        ]
    }