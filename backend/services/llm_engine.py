from groq import AsyncGroq
from backend.config import settings  # adjust import path to match your config.py location
import json
import logging

logger = logging.getLogger(__name__)

# Single client instance, reused across requests — not recreated per call.
# AsyncGroq because FastAPI is async; using the sync Groq() here would
# block the event loop on every LLM call, killing concurrent request handling.
client = AsyncGroq(api_key=settings.groq_api_key)  # match the exact field name from your config.py

# Model split — small/fast for parsing (structured, low creativity needed),
# larger for explanation (needs to write coherent natural language)
PARSE_MODEL = "openai/gpt-oss-20b"       # smaller/faster — good for structured filter extraction
EXPLAIN_MODEL = "openai/gpt-oss-120b"    # larger — better for natural-language explanation quality


async def parse_query(user_query: str) -> dict:
    """
    Takes a raw user query (English or Hinglish) and returns structured filters.
    Fails soft: returns an empty dict on any error, so the caller can fall
    back to pure semantic/TF-IDF search instead of crashing — same
    fail-soft pattern you already used in rag_engine.py.
    """
    system_prompt = """You are a query parser for a restaurant recommendation app.
Extract structured filters from the user's query. Respond ONLY with valid JSON,
no preamble, no markdown code fences.

Schema:
{
  "cuisine": string or null,
  "budget": "low" | "medium" | "high" or null,
  "location_hint": string or null,
  "dietary": string or null,
  "cleaned_query": string  // the query rewritten in plain English for semantic search
}

If a field isn't mentioned, use null. Always fill cleaned_query."""

    try:
        response = await client.chat.completions.create(
            model=PARSE_MODEL,
            messages=[
                {"role": "system", "content": system_prompt},
                {"role": "user", "content": user_query},
            ],
            temperature=0.1,  # low temp — we want consistent structured output, not creativity
            response_format={"type": "json_object"},  # Groq's JSON mode — forces valid JSON
        )
        raw = response.choices[0].message.content
        return json.loads(raw)

    except Exception as e:
        logger.warning(f"Query parsing failed, falling back to raw query: {e}")
        return {}