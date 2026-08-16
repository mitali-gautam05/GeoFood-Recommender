"""
Phase 1 - Steps 2 & 3: multilingual-e5-large embeddings (via fastembed,
ONNX quantized) + ChromaDB index build. Run once (or whenever restaurant
data changes). This is offline, not part of the request-time path.

Switched from BGE-M3 to multilingual-e5-large: fastembed does not ship a
BGE-M3 build. e5-large-multilingual gives the same goal (strong Hindi /
multilingual retrieval) and is ONNX-optimized for CPU, which BGE-M3 (via
FlagEmbedding/PyTorch) was not on this machine.

Note: E5 models expect a "passage: " prefix on indexed text and a
"query: " prefix on search queries -- this is part of how the model was
trained and meaningfully improves retrieval quality.

Install:
    pip install -U fastembed chromadb tqdm pandas pyarrow

Run:
    python rag/embed_index.py
"""

import pandas as pd
import chromadb
from pathlib import Path
from tqdm import tqdm
from fastembed import TextEmbedding

BACKEND_DIR = Path(__file__).resolve().parent.parent  # -> backend/
SERIALIZED_PATH = BACKEND_DIR / "model_artifacts" / "rag" / "serialized_restaurants.parquet"
CHROMA_DIR = BACKEND_DIR / "model_artifacts" / "rag" / "chroma_store"
COLLECTION_NAME = "geotaste_restaurants"
BATCH_SIZE = 32

# For Day 2 testing: set to a small number (e.g. 500) to index only a subset.
# Set to None for the full run (Day 3).
SUBSET_SIZE = None


def main():
    if not SERIALIZED_PATH.exists():
        print(f"ERROR: could not find {SERIALIZED_PATH}")
        print("Run serialize.py first to generate it.")
        return

    df = pd.read_parquet(SERIALIZED_PATH)
    if SUBSET_SIZE is not None:
        df = df.head(SUBSET_SIZE)
        print(f"SUBSET MODE: using only the first {SUBSET_SIZE} rows for testing")
    print(f"Loaded {len(df)} serialized restaurant records")

    print("Loading multilingual-e5-large (fastembed, ONNX quantized)...")
    model = TextEmbedding(model_name="intfloat/multilingual-e5-large")

    client = chromadb.PersistentClient(path=str(CHROMA_DIR))
    collection = client.get_or_create_collection(
        name=COLLECTION_NAME,
        metadata={"hnsw:space": "cosine"},
    )

    texts = df["rag_text"].tolist()
    ids = df["rag_id"].tolist()
    metadata_cols = [c for c in df.columns if c not in ("rag_text", "rag_id")]
    metadatas = df[metadata_cols].fillna("").astype(str).to_dict(orient="records")

    for start in tqdm(range(0, len(texts), BATCH_SIZE), desc="Embedding + indexing"):
        end = start + BATCH_SIZE
        batch_texts = texts[start:end]
        batch_ids = ids[start:end]
        batch_meta = metadatas[start:end]

        # E5 models expect a "passage: " prefix on indexed documents
        prefixed_texts = [f"passage: {t}" for t in batch_texts]
        batch_embeddings = [vec.tolist() for vec in model.embed(prefixed_texts)]

        collection.add(
            ids=batch_ids,
            embeddings=batch_embeddings,
            documents=batch_texts,
            metadatas=batch_meta,
        )

    print(f"\nIndexed {collection.count()} restaurants into ChromaDB at {CHROMA_DIR}")


if __name__ == "__main__":
    main()