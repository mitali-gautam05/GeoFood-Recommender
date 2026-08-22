from groq import AsyncGroq
from backend.config import settings
import json
import logging

logger = logging.getLogger(__name__)
client = AsyncGroq(api_key=settings.GROQ_API_KEY)

PARSE_MODEL = "openai/gpt-oss-20b"       # smaller/faster — good for structured filter extraction
EXPLAIN_MODEL = "openai/gpt-oss-120b" 


async def parse_query(user_query: str) -> dict:
    system_prompt = """You are a query parser for a restaurant recommendation app.
Extract structured filters from the user's query. Respond ONLY with valid JSON,
no preamble, no markdown code fences.

Schema:
{
  "cuisine": string or null,
  "budget": "low" | "medium" | "high" or null,
  "location_hint": string or null,
  "dietary": string or null,
  "cleaned_query": string
}

If a field isn't mentioned, use null. Always fill cleaned_query."""

    try:
        response = await client.chat.completions.create(
            model=PARSE_MODEL,
            messages=[
                {"role": "system", "content": system_prompt},
                {"role": "user", "content": user_query},
            ],
            temperature=0.1,
            response_format={"type": "json_object"},
        )
        raw = response.choices[0].message.content
        return json.loads(raw)

    except Exception as e:
        logger.warning(f"Query parsing failed, falling back to raw query: {e}")
        return {}