"""
One-time fix: your ChromaDB metadata currently stores price/rating as
STRINGS ("200.0") because embed_index.py did `.astype(str)` on the whole
metadata block. ChromaDB's numeric filters ($lte, $gt, etc.) only work on
actual int/float values -- so hard budget filtering silently fails against
string-typed metadata.

This does NOT re-embed anything (the vectors are already correct) -- it
only updates the stored metadata in place, batch by batch, using
collection.update(). Much faster than re-running embed_index.py.

Run from backend/:
    python rag/fix_metadata_types.py
"""

from pathlib import Path
import pandas as pd
import chromadb
from tqdm import tqdm

BACKEND_DIR = Path(__file__).resolve().parent.parent
SERIALIZED_PATH = BACKEND_DIR / "model_artifacts" / "rag" / "serialized_restaurants.parquet"
CHROMA_DIR = BACKEND_DIR / "model_artifacts" / "rag" / "chroma_store"
COLLECTION_NAME = "geotaste_restaurants"
BATCH_SIZE = 500

# Columns that must be numeric for filtering to work.
NUMERIC_COLS = ["price", "rating"]
# Columns that stay as strings (categorical / exact-match use cases).
STRING_COLS = ["name", "city", "food_type_display", "price_bucket"]


def main():
    df = pd.read_parquet(SERIALIZED_PATH)
    print(f"Loaded {len(df)} records to fix metadata for")

    client = chromadb.PersistentClient(path=str(CHROMA_DIR))
    collection = client.get_collection(COLLECTION_NAME)

    ids = df["rag_id"].tolist()

    metadatas = []
    for _, row in df.iterrows():
        meta = {}
        for col in STRING_COLS:
            if col in df.columns:
                meta[col] = str(row.get(col, "") or "")
        for col in NUMERIC_COLS:
            if col in df.columns:
                val = row.get(col)
                # ChromaDB metadata can't store NaN/None -- use a sentinel
                meta[col] = float(val) if pd.notna(val) else -1.0
        metadatas.append(meta)

    for start in tqdm(range(0, len(ids), BATCH_SIZE), desc="Updating metadata"):
        end = start + BATCH_SIZE
        collection.update(
            ids=ids[start:end],
            metadatas=metadatas[start:end],
        )

    print("Metadata fixed. Verifying with a sample query...")
    sample = collection.get(ids=[ids[0]], include=["metadatas"])
    print(sample["metadatas"][0])
    print("`price` and `rating` above should be numbers, not strings in quotes.")


if __name__ == "__main__":
    main()