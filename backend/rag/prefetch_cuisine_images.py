"""
rag/prefetch_cuisine_images.py

One-time script: fetches one representative photo per canonical cuisine
tag from Unsplash and stores the URL permanently in Redis. Run this once
(and again only if you want to refresh the image set) -- recommend(),
chat(), and converse() never call Unsplash themselves, they only read
what this script writes.

Run from backend/ as cwd:
    python rag/prefetch_cuisine_images.py
"""
import sys
import time
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

import requests
from config import settings
from services.cache import get_redis
from services.image_service import CANONICAL_CUISINE_TAGS, _IMAGE_KEY_PREFIX

UNSPLASH_SEARCH_URL = "https://api.unsplash.com/search/photos"


def fetch_image_for_tag(tag: str) -> str | None:
    try:
        response = requests.get(
            UNSPLASH_SEARCH_URL,
            params={"query": f"{tag} food", "per_page": 1, "orientation": "landscape"},
            headers={"Authorization": f"Client-ID {settings.UNSPLASH_ACCESS_KEY}"},
            timeout=10,
        )
        response.raise_for_status()
        results = response.json().get("results", [])
        if not results:
            print(f"  no results for '{tag}'")
            return None
        return results[0]["urls"]["regular"]
    except Exception as e:
        print(f"  FAILED for '{tag}': {e}")
        return None


def main():
    if not settings.UNSPLASH_ACCESS_KEY:
        print("UNSPLASH_ACCESS_KEY not set in .env -- aborting.")
        return

    r = get_redis()
    if r is None:
        print("Redis unavailable -- aborting (images must be cached to Redis).")
        return

    print(f"Prefetching images for {len(CANONICAL_CUISINE_TAGS)} canonical cuisine tags...")
    ok, skipped = 0, 0
    for tag in CANONICAL_CUISINE_TAGS:
        key = _IMAGE_KEY_PREFIX + tag
        if r.get(key):
            print(f"[{tag}] already cached, skipping")
            skipped += 1
            continue

        url = fetch_image_for_tag(tag)
        if url:
            r.set(key, url)  # no TTL -- permanent, refresh manually if ever needed
            print(f"[{tag}] cached")
            ok += 1
        time.sleep(1.2)  # stay comfortably under Unsplash's demo rate limit (50/hour)

    print(f"\nDone. {ok} newly cached, {skipped} already present, "
          f"{len(CANONICAL_CUISINE_TAGS) - ok - skipped} failed.")


if __name__ == "__main__":
    main()