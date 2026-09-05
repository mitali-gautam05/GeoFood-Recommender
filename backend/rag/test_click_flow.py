"""
rag/test_click_flow.py

Phase 3: two-turn click-intent test via run_chat_graph() directly.

Turn 1: a normal search (produces recommendations, stored in session
        history with name+cuisine per result via finalize_node).
Turn 2: a click/selection follow-up ("the first one, I liked it") --
        should be classified intent="click", matched against Turn 1's
        stored results, and result in record_click() being called with
        the correct cuisine (not a hallucinated one).

Run from backend/ as cwd:
    python rag/test_click_flow.py
"""
import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent.parent))
import asyncio
from services.session_store import clear_session, get_session_history
from services.chat_graph import run_chat_graph

USERNAME = "demo_user"
CITY = "mangalore"


async def main():
    clear_session(USERNAME)
    print("Session cleared.")

    print("=" * 60)
    print("TURN 1: 'affordable biryani'")
    print("=" * 60)
    result1 = await run_chat_graph(
        username=USERNAME,
        query="affordable biryani",
        city=CITY,
    )
    recs = result1.get("recommendations", [])
    if not recs:
        print("No recommendations returned -- can't test click flow without results.")
        return

    print(f"is_followup: {result1.get('is_followup')}")
    for r in recs:
        print(f"  {r['name']:30s} {r.get('cuisine', ''):15s} Rs {r.get('price')}")

    first_name = recs[0]["name"]
    first_cuisine = recs[0].get("cuisine")

    # Sanity check: did finalize_node actually persist results to session?
    history = get_session_history(USERNAME)
    stored_results = history[-1].get("results", []) if history else []
    print(f"\nStored in session after turn 1: {stored_results}")
    if not any(r.get("name") == first_name for r in stored_results):
        print("WARNING: first result not found in stored session history -- "
              "click matching in turn 2 will fail. Check finalize_node.")

    print("=" * 60)
    print(f"TURN 2: 'the first one, I loved it!'  (should be intent=click, "
          f"matching '{first_name}' -> cuisine '{first_cuisine}')")
    print("=" * 60)
    result2 = await run_chat_graph(
        username=USERNAME,
        query="the first one, I loved it!",
        city=CITY,
    )

    print(f"status: {result2.get('status')}")
    print(f"clicked_name: {result2.get('clicked_name')}")
    print(f"cuisine recorded: {result2.get('cuisine')}")
    print(f"is_followup: {result2.get('is_followup')}")

    # Verdict
    if result2.get("status") == "click_recorded":
        if result2.get("clicked_name") == first_name and result2.get("cuisine") == first_cuisine:
            print("\nPASS: click correctly matched to turn 1's top result, correct cuisine recorded.")
        else:
            print(f"\nFAIL: click recorded but mismatched. Expected name={first_name}, "
                  f"cuisine={first_cuisine}; got name={result2.get('clicked_name')}, "
                  f"cuisine={result2.get('cuisine')}")
    elif result2.get("status") == "click_unresolved":
        print(f"\nFAIL: click was not resolved. Message: {result2.get('message')}")
    else:
        print(f"\nFAIL: unexpected status '{result2.get('status')}' -- "
              f"intent classification likely didn't detect this as a click at all "
              f"(check resolve_followup's intent output).")


if __name__ == "__main__":
    asyncio.run(main())