# backend/models/user_click.py
# Persists every recordClick() call from Flutter into PostgreSQL.
# Previously clicks lived only in RAM (USER_SESSIONS dict) and were
# lost on every server restart — this fixes that.

from datetime import datetime
from sqlalchemy import Column, Integer, String, DateTime, Index
from database import Base


class UserClick(Base):
    __tablename__ = "user_clicks"

    id         = Column(Integer, primary_key=True, index=True)
    username   = Column(String,  nullable=False, index=True)
    food_type  = Column(String,  nullable=False)
    city       = Column(String,  nullable=True)   # optionally store city context
    clicked_at = Column(DateTime, default=datetime.utcnow, nullable=False)

    # Composite index: fast lookup of "all clicks by username in last N days"
    __table_args__ = (
        Index("ix_user_clicks_username_clicked_at", "username", "clicked_at"),
    )