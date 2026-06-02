from sqlalchemy import Column, Integer, String, Float, DateTime
from datetime import datetime
from database import Base


class Place(Base):
    __tablename__ = "places"

    id = Column(Integer, primary_key=True, index=True)
    osm_id = Column(String, unique=True, index=True)
    name = Column(String, nullable=False)

    lat = Column(Float, nullable=False)
    lon = Column(Float, nullable=False)

    type = Column(String)
    cuisine = Column(String)

    rating = Column(Float, default=4.0)

    fetched_at = Column(DateTime, default=datetime.utcnow)