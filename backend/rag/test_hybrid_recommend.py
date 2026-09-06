"""
 checking : verify semantic_score is being blended into sim_score
inside recommend(), without needing the full API/Flutter chain.

Run from backend/:
    python rag/test_hybrid_recommend.py
"""

import sys
from pathlib import Path

# so `from services.recommender import recommend` works when run from backend/
sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from services.recommender import recommend

result = recommend(
    username="test_user",
    query="sasta biryani nearby",
    city="mangalore",   # change to a city you know exists in your dataset
    budget=200,
    top_n=5,
    db=None,             # no DB session -> click history / cache both skipped, that's fine for this test
)

print(f"Status: {result['status']}")
print(f"Matched city: {result.get('matched_city')}\n")

if result["status"] != "ok":
    print("No recommendations returned -- check the city name exists in your dataset.")
else:
    for r in result["recommendations"]:
        print(
            f"{r['name']:35s} | sim_score={r['sim_score']:.3f} | "
            f"rating={r['rating']} | price={r['price']} | {r['why_recommended']}"
        )
