# backend/models/user.py
# Phase 4: added `city` column.
# server_default='' means existing rows in PostgreSQL get an empty string
# automatically — no manual migration needed if you use create_all().
# If you use Alembic: alembic revision --autogenerate -m "add city to users"

from datetime import datetime
from sqlalchemy import Column, Integer, String, Boolean, DateTime
from database import Base


class User(Base):
    __tablename__ = "users"

    id              = Column(Integer, primary_key=True, index=True)
    email           = Column(String, unique=True, index=True)
    username        = Column(String, index=True)
    hashed_password = Column(String)
    is_active       = Column(Boolean, default=True)
    city            = Column(String, server_default="", default="")  # ← Phase 4
    created_at      = Column(DateTime, default=datetime.utcnow)