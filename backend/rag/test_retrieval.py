"""
Quick sanity check for the ChromaDB index. Use this to test both English
and Hinglish/Hindi queries before wiring into the API.

Run:
    python rag/test_retrieval.py "sasta biryani nearby"
    python rag/test_retrieval.py "affordable North Indian food"
"""

import sys
from pathlib import Path
import chromadb
from fastembed import TextEmbedding

BACKEND_DIR = Path(__file__).resolve().parent.parent  # -> backend/
CHROMA_DIR = BACKEND_DIR / "model_artifacts" / "rag" / "chroma_store"
COLLECTION_NAME = "geotaste_restaurants"


def main():
    query = sys.argv[1] if len(sys.argv) > 1 else "affordable biryani"

    if not CHROMA_DIR.exists():
        print(f"ERROR: could not find ChromaDB store at {CHROMA_DIR}")
        print("Run embed_index.py first to build the index.")
        return

    model = TextEmbedding(model_name="intfloat/multilingual-e5-large")
    client = chromadb.PersistentClient(path=str(CHROMA_DIR))
    collection = client.get_collection(COLLECTION_NAME)

    # E5 models expect a "query: " prefix on search queries
    query_vec = list(model.embed([f"query: {query}"]))[0].tolist()
    results = collection.query(query_embeddings=[query_vec], n_results=5)

    print(f"Query: {query}\n")
    for doc, meta, dist in zip(
        results["documents"][0], results["metadatas"][0], results["distances"][0]
    ):
        print(f"[similarity {1 - dist:.3f}] {doc}")
        print(f"    meta: {meta}\n")


if __name__ == "__main__":
    main()