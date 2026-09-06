"""
Resets demo_user's session, then runs two turns through the LangGraph
converse flow (run_chat_graph) back to back -- an initial query and a
follow-up -- to verify follow-up resolution end-to-end without needing
to manually hit /docs twice.

Run from backend/:
    python rag/test_followup_flow.py
"""

import asyncio
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from services.session_store import clear_session
from services.chat_graph import run_chat_graph


async def main():
    username = "demo_user"
    city = "mangalore"

    clear_session(username)
    print("Session cleared.\n")

    print("=" * 60)
    print("TURN 1: 'affordable biryani'")
    print("=" * 60)
    result1 = await run_chat_graph(username=username, query="affordable biryani", city=city)
    print(f"is_followup: {result1.get('is_followup')}")
    print(f"parsed_filters: {result1.get('parsed_filters')}")
    print("Top result:", result1["recommendations"][0]["name"], "-",
          "Rs", result1["recommendations"][0]["price"])

    print("\n" + "=" * 60)
    print("TURN 2: 'cheaper option?'  (should be a follow-up)")
    print("=" * 60)
    result2 = await run_chat_graph(username=username, query="cheaper option?", city=city)
    print(f"is_followup: {result2.get('is_followup')}")
    print(f"parsed_filters: {result2.get('parsed_filters')}")
    print("\nAll results, turn 2:")
    for r in result2["recommendations"]:
        print(f"  {r['name']:30s} Rs {r['price']}")


if __name__ == "__main__":
    asyncio.run(main())