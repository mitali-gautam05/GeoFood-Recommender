"""
Phase 1 - Step 1: Structured-to-text serialization
Converts each row of the existing restaurants.parquet into a natural-language
text blob, ready for embedding. This does NOT touch recommender.py.

Adjust COLUMN_MAP below to match your actual restaurants.parquet column names.

Run:
    python serialize.py

Output:
    backend/model_artifacts/rag/serialized_restaurants.parquet
"""

import pandas as pd
from pathlib import Path

# ---- matched to your actual restaurants.parquet columns ----
COLUMN_MAP = {
    "name": "name",
    "city": "city",
    "cuisine": "food_type_display",
    "rating": "rating",
    "price": "price",
    "price_bucket": "price_bucket",  # already computed in your dataset
}

# Resolve paths relative to this script's location (backend/rag/serialize.py),
# so it works no matter which directory you run it from.
BACKEND_DIR = Path(__file__).resolve().parent.parent  # -> backend/
INPUT_PATH = BACKEND_DIR / "model_artifacts" / "restaurants.parquet"
OUTPUT_DIR = BACKEND_DIR / "model_artifacts" / "rag"
OUTPUT_PATH = OUTPUT_DIR / "serialized_restaurants.parquet"


def format_cuisine(cuisine: str) -> str:
    """'North, Indian, Street Food' -> 'North, Indian, and Street Food'"""
    items = [c.strip() for c in cuisine.split(",") if c.strip()]
    if len(items) <= 1:
        return cuisine
    return ", ".join(items[:-1]) + f", and {items[-1]}"


def serialize_row(row: pd.Series) -> str:
    """Turn one restaurant record into a natural-language description."""
    name = row.get(COLUMN_MAP["name"], "This restaurant")
    city = row.get(COLUMN_MAP["city"], "")
    cuisine = row.get(COLUMN_MAP["cuisine"], "")
    rating = row.get(COLUMN_MAP["rating"], None)
    price = row.get(COLUMN_MAP["price"], None)
    bucket = row.get(COLUMN_MAP["price_bucket"], None)

    text = f"{name} is a restaurant"
    if city:
        text += f" located in {city}"
    if cuisine:
        text += f", serving {format_cuisine(cuisine)} cuisine"
    text += ". "

    text += f"It falls in the {bucket} price range" if pd.notna(bucket) and bucket else "Pricing is unspecified"
    if pd.notna(price):
        text += f", roughly Rs {int(price)} for two."
    else:
        text += "."

    if pd.notna(rating):
        text += f" It has a rating of {rating}/5."

    return text


def main():
    if not INPUT_PATH.exists():
        print(f"ERROR: could not find {INPUT_PATH}")
        print("Check that restaurants.parquet actually lives at that path.")
        return

    df = pd.read_parquet(INPUT_PATH)
    print(f"Loaded {len(df)} restaurants from {INPUT_PATH}")

    df["rag_text"] = df.apply(serialize_row, axis=1)
    df["rag_id"] = df.index.astype(str)

    keep_cols = ["rag_id", "rag_text"] + list(COLUMN_MAP.values())
    keep_cols = [c for c in keep_cols if c in df.columns or c in ("rag_id", "rag_text")]

    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    df[keep_cols].to_parquet(OUTPUT_PATH)

    print(f"Saved serialized text for {len(df)} restaurants -> {OUTPUT_PATH}")
    print("\nSample:")
    print(df["rag_text"].iloc[0])


if __name__ == "__main__":
    main()