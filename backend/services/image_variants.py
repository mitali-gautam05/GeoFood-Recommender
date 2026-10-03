"""
services/image_variants.py

Picks a per-RESTAURANT photo from the per-cuisine pools that
rag/prefetch_cuisine_images.py (v2) stores in Redis, so restaurants that
share a cuisine no longer all show the same picture.

How it picks:
  1. find every canonical cuisine tag contained in the restaurant's food_type
     (e.g. "biryani, hyderabadi, lucknowi" -> 3 tags) and merge their pools
     -> a bigger pool means more variety.
  2. choose one photo with a STABLE hash of the restaurant name
     (md5, not Python's hash(), which changes every process). Same
     restaurant -> same photo on every request and every restart.
  3. if no pool exists (script not run yet / Redis down), fall back to the
     old single-photo get_cuisine_image_url() so nothing breaks.
"""
import hashlib
import json
import logging

from services.cache import get_redis
from services.image_service import (
    CANONICAL_CUISINE_TAGS,
    _IMAGE_KEY_PREFIX,
    get_cuisine_image_url,
)

logger = logging.getLogger(__name__)

# tag -> list[str]; avoids a Redis round-trip per restaurant per request.
# Restart the backend after re-running the prefetch script to pick up changes.
_POOL_CACHE: dict[str, list[str]] = {}


def _pool_for_tag(r, tag: str) -> list[str]:
    if tag in _POOL_CACHE:
        return _POOL_CACHE[tag]
    pool: list[str] = []
    try:
        raw = r.get(f"{_IMAGE_KEY_PREFIX}{tag}:list")
        if raw:
            if isinstance(raw, bytes):
                raw = raw.decode("utf-8")
            data = json.loads(raw)
            if isinstance(data, list):
                pool = [u for u in data if isinstance(u, str)]
    except Exception as e:
        logger.warning(f"image pool read failed for '{tag}': {e}")
    if pool:                      # only memoise real pools, so a miss is retried
        _POOL_CACHE[tag] = pool
    return pool


def get_restaurant_image_url(food_type: str, name: str) -> str | None:
    r = get_redis()
    if r is not None:
        food = str(food_type).lower()
        pool: list[str] = []
        for tag in CANONICAL_CUISINE_TAGS:
            if tag in food:
                for url in _pool_for_tag(r, tag):
                    if url not in pool:
                        pool.append(url)
        if pool:
            digest = hashlib.md5(str(name).lower().encode("utf-8")).hexdigest()
            return pool[int(digest, 16) % len(pool)]
    return get_cuisine_image_url(food_type)   # old behaviour as fallback