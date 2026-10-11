"""
rag/prefetch_cuisine_images.py   (v2: photo POOLS instead of one photo per tag)

Fetches several representative photos per canonical cuisine tag from
Unsplash and stores them in Redis as a JSON list under
    <_IMAGE_KEY_PREFIX><tag>:list
so that different restaurants of the same cuisine can show DIFFERENT photos
(see services/image_variants.py, which picks one per restaurant by name hash).

The old single-photo key (<_IMAGE_KEY_PREFIX><tag>) is left untouched, so
get_cuisine_image_url() keeps working as a fallback.

If a tag's plain "<tag> food" query returns too few photos, the extra query
variants in QUERY_OVERRIDES are tried and their results merged, so thin
regional tags (hyderabadi, andhra, ...) still end up with a usable pool.

Run from backend/ as cwd:
    python rag/prefetch_cuisine_images.py            # only tags with no pool yet
    python rag/prefetch_cuisine_images.py --refresh  # rebuild every pool
"""
import json
import sys
import time
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

import requests
from config import settings
from services.cache import get_redis
from services.image_service import CANONICAL_CUISINE_TAGS, _IMAGE_KEY_PREFIX

UNSPLASH_SEARCH_URL = "https://api.unsplash.com/search/photos"
PER_PAGE = 10          # photos requested per query
MIN_POOL = 8           # keep trying query variants until the pool has this many

QUERY_OVERRIDES: dict[str, list[str]] = {
    "hyderabadi": ["hyderabadi biryani", "hyderabadi cuisine", "indian biryani"],
    "andhra":     ["andhra cuisine", "andhra meals", "south indian food"],
}


def _query_variants(tag: str) -> list[str]:
    return [f"{tag} food"] + QUERY_OVERRIDES.get(tag, [])


def _search_many(query: str) -> list[str]:
    try:
        response = requests.get(
            UNSPLASH_SEARCH_URL,
            params={"query": query, "per_page": PER_PAGE, "orientation": "landscape"},
            headers={"Authorization": f"Client-ID {settings.UNSPLASH_ACCESS_KEY}"},
            timeout=10,
        )
        response.raise_for_status()
        results = response.json().get("results", [])
        return [r["urls"]["regular"] for r in results]
    except Exception as e:
        print(f"    FAILED for query '{query}': {e}")
        return []


def fetch_pool_for_tag(tag: str) -> list[str]:
    pool: list[str] = []
    variants = _query_variants(tag)
    for i, query in enumerate(variants):
        for url in _search_many(query):
            if url not in pool:
                pool.append(url)
        if len(pool) >= MIN_POOL:
            break
        if i < len(variants) - 1:
            print(f"  pool has {len(pool)} for '{tag}', trying next query variant")
            time.sleep(1.2)
    return pool


def main():
    refresh = "--refresh" in sys.argv

    if not settings.UNSPLASH_ACCESS_KEY:
        print("UNSPLASH_ACCESS_KEY not set in .env -- aborting.")
        return

    r = get_redis()
    if r is None:
        print("Redis unavailable -- aborting (images must be cached to Redis).")
        return

    print(f"Building photo pools for {len(CANONICAL_CUISINE_TAGS)} cuisine tags "
          f"({'refreshing all' if refresh else 'new only'})...")
    ok, skipped, failed = 0, 0, 0
    for tag in CANONICAL_CUISINE_TAGS:
        list_key = f"{_IMAGE_KEY_PREFIX}{tag}:list"
        if not refresh and r.get(list_key):
            print(f"[{tag}] pool already cached, skipping")
            skipped += 1
            continue

        pool = fetch_pool_for_tag(tag)
        if pool:
            r.set(list_key, json.dumps(pool))   # no TTL -- permanent
            # make sure the old single-photo key exists too (fallback path)
            if not r.get(_IMAGE_KEY_PREFIX + tag):
                r.set(_IMAGE_KEY_PREFIX + tag, pool[0])
            print(f"[{tag}] cached {len(pool)} photos")
            ok += 1
        else:
            print(f"[{tag}] FAILED -- no photos found")
            failed += 1
        time.sleep(1.2)  # stay under Unsplash's demo rate limit (50/hour)

    print(f"\nDone. {ok} pools built, {skipped} already present, {failed} failed.")


if __name__ == "__main__":
    main()