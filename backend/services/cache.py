# backend/services/cache.py

import json
import hashlib
import logging
from datetime import datetime, timedelta
from typing import Optional

import redis
from sqlalchemy.orm import Session

from config import settings

logger = logging.getLogger(__name__)

_redis_client: Optional[redis.Redis] = None
CACHE_TTL_SECONDS = 1800  # 30 minutes


def get_redis() -> Optional[redis.Redis]:
    """Return Redis client using REDIS_URL, or None if unavailable."""
    global _redis_client
    if _redis_client is not None:
        return _redis_client
    try:
        # FIX: use REDIS_URL directly — matches your .env
        url = getattr(settings, "REDIS_URL", "redis://localhost:6379/0")
        _redis_client = redis.from_url(
            url,
            decode_responses=True,
            socket_connect_timeout=2,
            socket_timeout=2,
        )
        _redis_client.ping()
        logger.info("✅ Redis connected via REDIS_URL")
        return _redis_client
    except Exception as e:
        logger.warning(f"⚠️  Redis unavailable ({e}) — falling through to DB/ML")
        _redis_client = None
        return None


def make_cache_key(
    city:         str,
    query:        str,
    budget:       float,
    mood:         Optional[str]  = None,
    time_slot:    Optional[str]  = None,
    weather_tags: Optional[list] = None,
) -> str:
    budget_bucket = round(budget / 50) * 50
    weather_str   = ",".join(sorted(weather_tags or []))
    raw           = f"{city.lower()}:{query.lower()}:{budget_bucket}:{mood or ''}:{time_slot or ''}:{weather_str}"
    short_hash    = hashlib.md5(raw.encode()).hexdigest()[:8]
    return f"recommend:{city.lower()}:{short_hash}"


# ── Layer 1: Redis ─────────────────────────────────────────────
def redis_get(key: str) -> Optional[dict]:
    r = get_redis()
    if r is None:
        return None
    try:
        raw = r.get(key)
        if raw:
            logger.debug(f"Redis HIT: {key}")
            return json.loads(raw)
    except Exception as e:
        logger.warning(f"Redis GET error: {e}")
    return None


def redis_set(key: str, value: dict) -> None:
    r = get_redis()
    if r is None:
        return
    try:
        r.setex(key, CACHE_TTL_SECONDS, json.dumps(value))
        logger.debug(f"Redis SET: {key} (TTL {CACHE_TTL_SECONDS}s)")
    except Exception as e:
        logger.warning(f"Redis SET error: {e}")


# ── Layer 2: PostgreSQL ────────────────────────────────────────
def pg_get(key: str, db: Session) -> Optional[dict]:
    try:
        from models.cached_result import CachedResult
        cutoff = datetime.utcnow() - timedelta(seconds=CACHE_TTL_SECONDS)
        row = (
            db.query(CachedResult)
            .filter(
                CachedResult.cache_key == key,
                CachedResult.created_at >= cutoff,
            )
            .first()
        )
        if row:
            logger.debug(f"PostgreSQL cache HIT: {key}")
            return json.loads(row.result_json)
    except Exception as e:
        logger.warning(f"PostgreSQL cache GET error: {e}")
    return None


def pg_set(key: str, value: dict, db: Session) -> None:
    try:
        from models.cached_result import CachedResult
        db.query(CachedResult).filter(CachedResult.cache_key == key).delete()
        db.add(CachedResult(
            cache_key   = key,
            result_json = json.dumps(value),
            created_at  = datetime.utcnow(),
        ))
        db.commit()
        logger.debug(f"PostgreSQL cache SET: {key}")
    except Exception as e:
        logger.warning(f"PostgreSQL cache SET error: {e}")
        db.rollback()


# ── Public API ─────────────────────────────────────────────────
def cache_get(key: str, db: Session) -> Optional[dict]:
    result = redis_get(key)
    if result is not None:
        return result
    result = pg_get(key, db)
    if result is not None:
        redis_set(key, result)   # backfill Redis from DB
        return result
    return None


def cache_set(key: str, value: dict, db: Session) -> None:
    redis_set(key, value)
    pg_set(key, value, db)