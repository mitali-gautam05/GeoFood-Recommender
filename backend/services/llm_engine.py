from groq import AsyncGroq
from config import settings  # matches your existing codebase convention (see database.py)
import json
import logging
import asyncio

logger = logging.getLogger(__name__)


async def _call_with_retry(coro_fn, max_retries: int = 3, base_delay: float = 1.0):
    """
    Retries a Groq call with exponential backoff, but ONLY for rate-limit
    errors -- other errors (bad request, auth failure, etc.) re-raise
    immediately so the caller's existing fail-soft except block handles
    them as before. This exists specifically for Groq's free-tier rate
    limits, which are easy to hit in a burst (e.g. a demo with several
    quick searches).
    """
    for attempt in range(max_retries):
        try:
            return await coro_fn()
        except Exception as e:
            is_rate_limit = "rate_limit" in str(e).lower() or "429" in str(e)
            if is_rate_limit and attempt < max_retries - 1:
                delay = base_delay * (2 ** attempt)
                logger.warning(
                    f"Groq rate limit hit, retrying in {delay}s "
                    f"(attempt {attempt + 1}/{max_retries})"
                )
                await asyncio.sleep(delay)
                continue
            raise

# Single client instance, reused across requests -- not recreated per call.
# AsyncGroq because FastAPI is async; using the sync Groq() here would
# block the event loop on every LLM call, killing concurrent request handling.
client = AsyncGroq(api_key=settings.GROQ_API_KEY)  # match the exact field name from your config.py

# Model split -- small/fast for parsing (structured, low creativity needed),
# larger for explanation (needs to write coherent natural language)
PARSE_MODEL = "openai/gpt-oss-20b"       # smaller/faster -- good for structured filter extraction
EXPLAIN_MODEL = "openai/gpt-oss-120b"    # larger -- better for natural-language explanation quality


async def parse_query(user_query: str) -> dict:
    """
    Takes a raw user query (English or Hinglish) and returns structured filters.
    Fails soft: returns an empty dict on any error, so the caller can fall
    back to pure semantic/TF-IDF search instead of crashing -- same
    fail-soft pattern already used in rag_engine.py.
    """
    system_prompt = """You are a query parser for a restaurant recommendation app.
Extract structured filters from the user's query. Respond ONLY with valid JSON,
no preamble, no markdown code fences.

Schema:
{
  "cuisine": string or null,           // e.g. "biryani", "north indian" -- used as a soft semantic signal.
  // Food-category words count as cuisine even when phrased as a shop/venue type:
  // "dessert shop" -> "dessert", "bakery" -> "bakery", "juice place" -> "juice".
  // Do NOT extract generic venue words alone ("restaurant", "place", "spot") as cuisine.
  "budget_max": integer or null,       // exact rupee ceiling if the user implies one, e.g. "under 200" -> 200. Do NOT bucket this into low/medium/high -- return the actual number.
  // For vague LOW-budget words, use: "cheap"/"sasta"/"budget friendly" -> 200, "affordable" -> 300.
  // For vague HIGH-budget words ("expensive", "high end", "fine dining", "premium", "luxury"), return null -- these describe a vibe/quality tier, not a numeric ceiling, and should NOT be forced into a number.
  // If truly no budget signal at all, use null.
  "location_hint": string or null,     // e.g. "near college", "malviya nagar" -- informational only, not enforced as a hard filter yet
  "dietary": string or null,           // e.g. "vegan", "jain" -- NOTE: passed through for semantic matching only; the dataset has no dedicated dietary column, so this cannot be enforced as a hard filter
  "cleaned_query": string              // the query rewritten in plain English for semantic search -- fold cuisine/dietary/vibe words in here, but NOT the budget number
}

If a field isn't mentioned, use null. Always fill cleaned_query."""

    try:
        response = await _call_with_retry(lambda: client.chat.completions.create(
            model=PARSE_MODEL,
            messages=[
                {"role": "system", "content": system_prompt},
                {"role": "user", "content": user_query},
            ],
            temperature=0.1,  # low temp -- we want consistent structured output, not creativity
            response_format={"type": "json_object"},  # Groq's JSON mode -- forces valid JSON
        ))
        raw = response.choices[0].message.content
        return json.loads(raw)

    except Exception as e:
        logger.warning(f"Query parsing failed, falling back to raw query: {e}")
        return {}


async def explain_recommendations(user_query: str, results: list) -> dict:
    """
    Takes the original user query and the already-ranked list of restaurant
    dicts (as returned by recommend()'s "recommendations" list) and
    generates a short natural-language explanation for each, grounded in
    the real data already computed (rating, price, cuisine, and the
    existing rule-based `why_recommended` signal).

    This is ADDITIVE -- recommender.py's existing rule-based
    `why_recommended` field is untouched. The caller merges this in as a
    separate field (e.g. `llm_explanation`), so if this call fails, the
    existing rule-based explanations still work fine on their own.

    Batches ALL results into a single LLM call (not one call per
    restaurant) -- keeps latency and Groq free-tier rate-limit usage down.

    Fails soft: returns {} on any error.
    """
    if not results:
        return {}

    context_lines = [
        f"- {r['name']} | cuisine: {r['cuisine']} | rating: {r['rating']} | "
        f"price: Rs {r['price']} | existing signals: {r['why_recommended']}"
        for r in results
    ]
    context_block = "\n".join(context_lines)

    system_prompt = """You are a friendly food recommendation assistant.
Given a user's search query and a list of already-ranked restaurants
(with their real data), write a short, natural 1-2 sentence explanation
for EACH restaurant, explaining why it fits the query. Ground every claim
in the data given -- do not invent facts (no made-up dishes, no claims
about ambience or service that aren't in the data).

Respond ONLY with valid JSON in this exact schema, no preamble:
{
  "explanations": {
    "<restaurant name>": "<1-2 sentence explanation>",
    ...
  }
}"""

    user_prompt = f"User query: {user_query}\n\nRestaurants:\n{context_block}"

    try:
        response = await _call_with_retry(lambda: client.chat.completions.create(
            model=EXPLAIN_MODEL,
            messages=[
                {"role": "system", "content": system_prompt},
                {"role": "user", "content": user_prompt},
            ],
            temperature=0.4,  # a little creativity for natural phrasing, still grounded in data
            response_format={"type": "json_object"},
        ))
        raw = response.choices[0].message.content
        parsed = json.loads(raw)
        explanations = parsed.get("explanations", {})

        # Grounding check: drop any explanation that mentions attributes
        # that literally don't exist in our data (ambience/service/decor/
        # amenities -- none of this is in the dataset schema). A dropped
        # entry just means the caller falls back to the existing
        # rule-based `why_recommended` field, which is always present --
        # so the user always sees a real reason, never a fabricated one.
        report = check_grounding(explanations)
        for flagged_name in report["flagged"]:
            explanations.pop(flagged_name, None)

        return explanations

    except Exception as e:
        logger.warning(f"Explanation generation failed, skipping LLM explanations: {e}")
        return {}


# Terms describing restaurant attributes that are NOT present anywhere in
# GeoTaste's data schema (name, cuisine, rating, price, rule-based
# why_recommended signals). The dataset has zero ambience/service/decor/
# amenity information -- so any explanation mentioning these is
# necessarily fabricated, not just possibly so.
HALLUCINATION_PRONE_TERMS = [
    "ambience", "ambiance", "decor", "décor", "interior", "aesthetic",
    "parking", "wifi", "wi-fi", "valet",
    "service", "staff", "waiter", "waitress", "hospitality",
    "music", "live band", "seating", "outdoor seating", "rooftop view",
    "cozy", "romantic", "candlelit",
]


def check_explanation_grounding(explanation_text: str) -> list:
    """
    Heuristic hallucination check for a single explanation string. Flags
    any words describing attributes that literally don't exist in
    GeoTaste's data schema.

    This is a keyword heuristic, not a complete guarantee -- it reliably
    catches one specific, common hallucination category (invented
    atmosphere/service/amenity claims) but won't catch every possible
    fabrication (e.g. an invented dish name, or an incorrect specific
    claim framed using only real-field vocabulary).
    """
    text_lower = explanation_text.lower()
    return [term for term in HALLUCINATION_PRONE_TERMS if term in text_lower]


def check_grounding(explanations: dict) -> dict:
    """
    Runs check_explanation_grounding() over a full explanations dict and
    reports a per-restaurant flag list plus an overall hallucination
    rate. Used both internally by explain_recommendations() (to drop
    ungrounded explanations before they reach the user) and standalone,
    e.g. from an eval script measuring hallucination rate over time.
    """
    flagged = {}
    for name, text in explanations.items():
        hits = check_explanation_grounding(text)
        if hits:
            flagged[name] = hits

    total = len(explanations)
    hallucination_rate = (len(flagged) / total * 100) if total else 0.0

    if flagged:
        logger.warning(
            f"Grounding check: {len(flagged)}/{total} explanations "
            f"({hallucination_rate:.1f}%) mention ungrounded terms: {flagged}"
        )

    return {
        "flagged": flagged,
        "hallucination_rate_pct": round(hallucination_rate, 1),
        "total_checked": total,
    }