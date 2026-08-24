"""
services/rag_engine.py

v2: hybrid retrieval -- structured hard filters (city, numeric budget)
combined with dense semantic search, plus progressive filter relaxation
when a strict filter combination returns nothing.

Design rationale (say this in interviews):
- city, budget_max -> hard ChromaDB metadata filters. Clean scalar data,
  filtering is the right tool.
- cuisine -> NOT a hard filter. food_type_display is a messy comma-joined
  string ("North, Indian, Biryani") -- exact-match filtering on that is
  unreliable. Instead cuisine is folded into the semantic query text
  (cleaned_query) and used for a lightweight post-retrieval substring
  boost. Right tool for messy categorical data.
- dietary -> the dataset has NO dedicated dietary column at all. This is
  a real data gap, not something to fake. dietary is passed through into
  the semantic query only -- flagged honestly as a known limitation.
"""

import logging
from pathlib import Path
import chromadb
from fastembed import TextEmbedding

logger = logging.getLogger(__name__)

BACKEND_DIR = Path(__file__).resolve().parent.parent
CHROMA_DIR = BACKEND_DIR / "model_artifacts" / "rag" / "chroma_store"
COLLECTION_NAME = "geotaste_restaurants"

_model = None
_collection = None


def _get_model():
    global _model
    if _model is None:
        _model = TextEmbedding(model_name="intfloat/multilingual-e5-large")
    return _model


def _get_collection():
    global _collection
    if _collection is None:
        client = chromadb.PersistentClient(path=str(CHROMA_DIR))
        _collection = client.get_collection(COLLECTION_NAME)
    return _collection


def _cuisine_boost(metadata: dict, cuisine: str) -> float:
    """Soft signal: +0.05 if the requested cuisine appears anywhere in
    the comma-joined food_type_display string. Not a hard filter."""
    if not cuisine:
        return 0.0
    food = str(metadata.get("food_type_display", "")).lower()
    return 0.05 if cuisine.lower() in food else 0.0


def _query_chroma(query_text: str, city: str, budget_max: float = None, top_k: int = 200) -> dict:
    """One ChromaDB query with the given hard filters. Returns
    {rag_id: similarity} or {} on failure."""
    try:
        model = _get_model()
        collection = _get_collection()

        query_vec = list(model.embed([f"query: {query_text}"]))[0].tolist()

        where_clause = {"city": city}
        if budget_max is not None:
            where_clause = {"$and": [{"city": city}, {"price": {"$lte": float(budget_max)}}]}

        results = collection.query(
            query_embeddings=[query_vec],
            n_results=top_k,
            where=where_clause,
            include=["distances", "metadatas"],
        )

        ids = results["ids"][0]
        distances = results["distances"][0]

        return {rid: (1 - dist) for rid, dist in zip(ids, distances)}

    except Exception as e:
        logger.warning(f"ChromaDB query failed (city={city}, budget_max={budget_max}): {e}")
        return {}


def get_semantic_scores(
    query: str,
    city: str,
    budget_max: float = None,
    cuisine: str = None,
    top_k: int = 200,
):
    """
    Hybrid retrieval with progressive relaxation.

    Tries filters strict-to-loose:
      1. city + budget_max
      2. city only (relax budget)
      3. neither returns anything -> report failure rather than silently
         dropping the city filter too (dropping city risks surfacing
         totally irrelevant-location results, which is worse than
         returning nothing with a clear reason).

    Stops at the first tier that returns results. Applies a cuisine
    soft-boost on top regardless of which tier succeeded.

    Returns (scores_dict, relaxed_notes) -- relaxed_notes is a list of
    human-readable strings describing what was relaxed, so the caller can
    tell the user what happened instead of silently returning different
    results than what they asked for.

    Fails soft throughout: any stage failing just moves to the next tier.
    """
    relaxed_notes = []

    if budget_max is not None:
        scores = _query_chroma(query, city, budget_max=budget_max, top_k=top_k)
        if scores:
            return _apply_cuisine_boost(scores, cuisine), relaxed_notes
        relaxed_notes.append(
            f"no matches under your budget in {city} -- showing all budgets instead"
        )

    scores = _query_chroma(query, city, budget_max=None, top_k=top_k)
    if scores:
        return _apply_cuisine_boost(scores, cuisine), relaxed_notes

    relaxed_notes.append(
        f"no restaurants found in {city} -- check the city name or try again later"
    )
    return {}, relaxed_notes


def _apply_cuisine_boost(scores: dict, cuisine: str) -> dict:
    if not cuisine:
        return scores
    try:
        collection = _get_collection()
        ids = list(scores.keys())
        fetched = collection.get(ids=ids, include=["metadatas"])
        boosted = {}
        for rid, meta in zip(fetched["ids"], fetched["metadatas"]):
            boosted[rid] = scores[rid] + _cuisine_boost(meta, cuisine)
        return boosted
    except Exception as e:
        logger.warning(f"Cuisine boost step failed, returning unboosted scores: {e}")
        return scores