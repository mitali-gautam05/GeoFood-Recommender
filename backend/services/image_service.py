"""
services/image_service.py

Cuisine-level food images, sourced once from Unsplash and cached in Redis
permanently (no TTL -- stock photos for a cuisine tag don't go stale).

Design choice: images are looked up per CANONICAL cuisine tag (the same
~32-tag vocabulary recommender.py's clean_food_type() already uses), not
per restaurant or per raw food_type string. A restaurant's raw food_type
is often a combination like "South, Indian, Biryani" -- fetching a
distinct image for every such combination would mean hundreds of
Unsplash calls and hundreds of cache keys for what's visually the same
handful of cuisines. Bounding to ~32 canonical tags means the entire
image set is prefetched once (see rag/prefetch_cuisine_images.py) and
every recommend()/chat()/converse() call only ever does a fast Redis GET
-- never a live Unsplash call at request time, so this adds no latency
and no extra outbound requests per user action.

NOTE: CANONICAL_CUISINE_TAGS must stay in sync with the `known` list
inside recommender.py's clean_food_type(). Duplicated here rather than
imported to avoid a circular import (recommender.py imports this module
to attach image_url to its output).
"""

import logging
from typing import Optional

from services.cache import get_redis

logger = logging.getLogger(__name__)

CANONICAL_CUISINE_TAGS = [
    "north indian", "south indian", "fast food", "street food",
    "chinese", "biryani", "beverages", "snacks", "desserts",
    "american", "mughlai", "hyderabadi", "andhra", "pizza",
    "sweets", "continental", "italian", "mexican", "punjabi",
    "seafood", "kebabs", "rolls", "burgers", "rajasthani",
    "gujarati", "lucknowi", "persian", "afghani", "kerala",
    "tandoor", "arabic", "indian",
]

_IMAGE_KEY_PREFIX = "cuisine_image:"


def get_primary_cuisine_tag(food_type: str) -> str:
    """
    Extracts the first canonical tag found in a raw food_type string,
    checked longest-first so "south indian" matches before the bare
    "indian" substring inside it -- same ordering trick clean_food_type()
    uses, kept consistent so the tag picked here is the same tag a human
    reading the cleaned cuisine label would recognize.
    Falls back to "indian" (a generic, always-cached tag) if nothing matches.
    """
    ft = str(food_type).lower()
    for tag in sorted(CANONICAL_CUISINE_TAGS, key=len, reverse=True):
        if tag in ft:
            return tag
    return "indian"


def get_cuisine_image_url(food_type: str) -> Optional[str]:
    """
    Fast Redis-only lookup -- never calls Unsplash at request time.
    Returns None (fails soft) if Redis is unavailable or the tag hasn't
    been prefetched yet, so a missing image never breaks a recommendation.
    """
    r = get_redis()
    if r is None:
        return None
    tag = get_primary_cuisine_tag(food_type)
    try:
        return r.get(_IMAGE_KEY_PREFIX + tag)
    except Exception as e:
        logger.warning(f"Cuisine image lookup failed for '{tag}': {e}")
        return None