"""
rag/test_retry_flow.py

Phase 3: verifies the graph-level retry loop (retrieve -> bump_retry ->
retrieve) actually triggers and widens the search on a genuine
zero-result turn.

Real restaurant data makes a *guaranteed* zero-result-then-success case
hard to pin down blindly (depends on what's actually in the dataset for
a given city/rating/cuisine combo). So this test patches
services.chat_graph's `recommend` directly: first call returns zero
recommendations, second call (after the graph loops back through
bump_retry) returns some -- deterministically proving the conditional
edge and retry_count bump work, independent of live data quirks.

Run from backend/ as cwd:
    python rag/test_retry_flow.py
"""
import asyncio
import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from unittest.mock import patch
from services.session_store import clear_session
import services.chat_graph as chat_graph_module

USERNAME = "demo_user"
CITY = "mangalore"

call_log = []


def fake_recommend(**kwargs):
    """First call returns zero results; second call (post-retry)
    returns one fabricated result. Kwargs mirror the real recommend()
    call made inside retrieve_node."""
    call_log.append(kwargs)
    if len(call_log) == 1:
        return {"status": "ok", "recommendations": [], "searched_city": kwargs.get("city")}
    return {
        "status": "ok",
        "recommendations": [
            {"name": "fallback place", "cuisine": "multi-cuisine", "rating": 3.0,
             "price": 250, "why_recommended": "widened search match"}
        ],
        "searched_city": kwargs.get("city"),
    }


async def main():
    clear_session(USERNAME)
    print("Session cleared.")

    with patch.object(chat_graph_module, "recommend", side_effect=fake_recommend):
        result = await chat_graph_module.run_chat_graph(
            username=USERNAME,
            query="extremely rare cuisine that does not exist",
            city=CITY,
            min_rating=4.9,
        )

    print(f"Number of retrieve() calls made: {len(call_log)}")
    for i, kwargs in enumerate(call_log):
        print(f"  Call {i+1}: cuisine={kwargs.get('cuisine')!r}, min_rating={kwargs.get('min_rating')}")

    recs = result.get("recommendations", [])
    print(f"Final recommendations: {[r['name'] for r in recs]}")

    if len(call_log) != 2:
        print(f"\nFAIL: expected exactly 2 retrieve calls (1 initial + 1 retry), got {len(call_log)}.")
        return

    first_call, second_call = call_log
    if second_call.get("cuisine") is not None:
        print("\nFAIL: retry call still has cuisine set -- retrieve_node isn't widening on retry.")
        return
    if second_call.get("min_rating") >= first_call.get("min_rating"):
        print("\nFAIL: retry call didn't ease min_rating.")
        return
    if not recs:
        print("\nFAIL: retry produced a second recommend() call but final result still has no recommendations.")
        return

    print("\nPASS: zero-result turn correctly triggered exactly one retry, "
          "widened filters (cuisine dropped, min_rating eased), and returned "
          "the retry's results.")


if __name__ == "__main__":
    asyncio.run(main())