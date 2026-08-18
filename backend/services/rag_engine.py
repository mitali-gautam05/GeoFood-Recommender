"""
services/rag_engine.py

Adds a semantic-retrieval signal on top of the existing TF-IDF `sim_score`
in recommender.py. Does NOT replace recommender.py's scoring pipeline --
it blends into the existing `sim_score` slot as a keyword+semantic hybrid.

Semantic scores come from the ChromaDB index built offline in backend/rag/
(serialize.py -> embed_index.py), using the same multilingual-e5-large
embedding model (via fastembed) that was used at indexing time. The
model and ChromaDB collection are loaded once at import time -- same
pattern as tfidf/scaler in recommender.py -- not reloaded per request.
"""

import logging
from pathlib import Path
import chromadb
from fastembed import TextEmbedding

logger = logging.getLogger(__name__)

BACKEND_DIR = Path(__file__).resolve().parent.parent
CHROMA_DIR = BACKEND_DIR / "model_artifacts" / "rag" / "chroma_store"
COLLECTION_NAME = "geotaste_restaurants"

# Loaded lazily, once, on first use.
_model = None
_collection = None


def _get_model():
    global _model
    if _model is None:
        logger.info("Loading multilingual-e5-large for semantic retrieval...")
        _model = TextEmbedding(model_name="intfloat/multilingual-e5-large")
    return _model


def _get_collection():
    global _collection
    if _collection is None:
        client = chromadb.PersistentClient(path=str(CHROMA_DIR))
        _collection = client.get_collection(COLLECTION_NAME)
    return _collection


def get_semantic_scores(query: str, city: str, top_k: int = 200) -> dict:
    """
    Returns {rag_id: semantic_similarity} for restaurants in `city` that
    semantically match `query`.

    rag_id matches the original df index from restaurants.parquet, as a
    string -- see the `city_df["rag_id"]` column added in recommender.py.

    Fails soft: returns {} on any error (e.g. ChromaDB not built yet, or
    a bad state) so recommend() can fall back to pure TF-IDF instead of
    crashing a live request.
    """
    try:
        model = _get_model()
        collection = _get_collection()

        # E5 convention: prefix search queries with "query: "
        query_vec = list(model.embed([f"query: {query}"]))[0].tolist()

        results = collection.query(
            query_embeddings=[query_vec],
            n_results=top_k,
            where={"city": city},
        )

        ids = results["ids"][0]
        distances = results["distances"][0]
        # ChromaDB collection was built with cosine space -> similarity = 1 - distance
        return {rid: 1 - dist for rid, dist in zip(ids, distances)}

    except Exception as e:
        logger.warning(f"Semantic retrieval failed, falling back to TF-IDF only: {e}")
        return {}