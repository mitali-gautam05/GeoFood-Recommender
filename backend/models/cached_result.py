# backend/models/cached_result.py
# Stores serialised ML results in PostgreSQL as Layer 2 cache.
# Rows older than 30 minutes are ignored by cache_get().
# You can add a cron job or pg_cron to DELETE old rows periodically,
# but it's not required — stale rows are simply never read.

from datetime import datetime
from sqlalchemy import Column, Integer, String, DateTime, Text, Index
from database import Base


class CachedResult(Base):
    __tablename__ = "cached_results"

    id          = Column(Integer, primary_key=True, index=True)
    cache_key   = Column(String(255), nullable=False, unique=True, index=True)
    result_json = Column(Text, nullable=False)          # serialised recommendations
    created_at  = Column(DateTime, default=datetime.utcnow, nullable=False)

    __table_args__ = (
        # Fast expiry check: WHERE cache_key = ? AND created_at >= ?
        Index("ix_cached_results_key_created", "cache_key", "created_at"),
    )