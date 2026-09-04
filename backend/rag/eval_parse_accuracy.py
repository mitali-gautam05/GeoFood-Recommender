"""
Measures parse_query() accuracy against the 20 hand-labeled queries in
eval_queries.py. Computes field-level exact-match accuracy per field and
overall -- this is the number to actually cite in a resume/interview
instead of "it seemed to work."

Run from backend/ (async, needs the Groq client from llm_engine):
    python rag/eval_parse_accuracy.py
"""

import asyncio
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from services.llm_engine import parse_query
from rag.eval_queries import EVAL_QUERIES

FIELDS_TO_SCORE = ["cuisine", "budget_max", "location_hint", "dietary"]


def normalize(value):
    """Lowercase strings for fair comparison; leave numbers/None as-is."""
    if isinstance(value, str):
        return value.strip().lower()
    return value


async def run_eval():
    field_correct = {f: 0 for f in FIELDS_TO_SCORE}
    field_total = {f: 0 for f in FIELDS_TO_SCORE}
    total_queries = len(EVAL_QUERIES)
    fully_correct = 0
    failures = []

    for i, case in enumerate(EVAL_QUERIES, 1):
        query = case["query"]
        expected = case["expected"]

        result = await parse_query(query)

        if not result:
            print(f"[{i}/{total_queries}] PARSE FAILED (empty dict): {query!r}")
            failures.append((query, "parse_query returned {}"))
            for f in FIELDS_TO_SCORE:
                field_total[f] += 1
            continue

        row_correct = True
        mismatches = []
        for field in FIELDS_TO_SCORE:
            field_total[field] += 1
            exp_val = normalize(expected.get(field))
            got_val = normalize(result.get(field))
            if exp_val == got_val:
                field_correct[field] += 1
            else:
                row_correct = False
                mismatches.append(f"{field}: expected={exp_val!r} got={got_val!r}")

        if row_correct:
            fully_correct += 1
        else:
            failures.append((query, "; ".join(mismatches)))

        status = "OK" if row_correct else "MISMATCH"
        print(f"[{i}/{total_queries}] {status}: {query!r}")

    print("\n" + "=" * 60)
    print("RESULTS")
    print("=" * 60)
    for field in FIELDS_TO_SCORE:
        acc = field_correct[field] / field_total[field] * 100
        print(f"  {field:15s}: {field_correct[field]}/{field_total[field]} ({acc:.1f}%)")

    overall_acc = fully_correct / total_queries * 100
    print(f"\n  Fully correct (all 4 fields): {fully_correct}/{total_queries} ({overall_acc:.1f}%)")

    if failures:
        print("\n" + "-" * 60)
        print("FAILURES (for debugging / prompt tuning)")
        print("-" * 60)
        for query, reason in failures:
            print(f"  - {query!r}\n    {reason}")


if __name__ == "__main__":
    asyncio.run(run_eval())