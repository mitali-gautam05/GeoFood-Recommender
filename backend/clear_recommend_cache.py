"""
clear_recommend_cache.py

Clears ONLY the cached recommend() results (Redis keys "recommend:*" and the
PostgreSQL cached_result rows), so cards pick up the new per-restaurant
photos immediately. Does NOT touch the cuisine photo pools in Redis.

Run from backend/ as cwd:
    python clear_recommend_cache.py --dry-run   # only SHOW what would be deleted
    python clear_recommend_cache.py             # actually delete
"""
import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent))

from services.cache import get_redis

DRY = "--dry-run" in sys.argv

# ── Redis: only keys that start with "recommend:" ─────────────────────────
r = get_redis()
if r is None:
    print("Redis unavailable -- skipped Redis part.")
else:
    to_delete, others = [], {}
    for key in r.scan_iter(count=500):
        if key.startswith("recommend:"):
            to_delete.append(key)
        else:
            prefix = key.split(":")[0] + ":"
            others[prefix] = others.get(prefix, 0) + 1

    print(f"Redis: {len(to_delete)} 'recommend:*' keys " +
          ("WOULD be deleted (dry run)." if DRY else "found."))
    if to_delete[:3]:
        print("  sample:", to_delete[:3])
    print("Redis keys that will NOT be touched, grouped by prefix:")
    for prefix, n in sorted(others.items()):
        print(f"  {prefix:<30} {n}")

    if not DRY:
        for key in to_delete:
            r.delete(key)
        print(f"Redis: deleted {len(to_delete)} keys (everything else untouched).")

# ── PostgreSQL: cached result rows ────────────────────────────────────────
SessionLocal = None
for mod_name in ("database", "db", "models.database", "core.database"):
    try:
        mod = __import__(mod_name, fromlist=["SessionLocal"])
        SessionLocal = getattr(mod, "SessionLocal", None)
        if SessionLocal:
            break
    except Exception:
        continue

if SessionLocal is None:
    print("PostgreSQL: couldn't find SessionLocal automatically. "
          "Not needed if you just wait 30 minutes -- rows older than that are ignored anyway.")
else:
    try:
        from models.cached_result import CachedResult
        db = SessionLocal()
        if DRY:
            n = db.query(CachedResult).count()
            print(f"PostgreSQL: {n} cached result rows WOULD be deleted (dry run).")
        else:
            n = db.query(CachedResult).delete()
            db.commit()
            print(f"PostgreSQL: deleted {n} cached result rows.")
        db.close()
    except Exception as e:
        print(f"PostgreSQL part failed: {e}")