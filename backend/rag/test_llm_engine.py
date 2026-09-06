# quick test script, backend/rag/test_llm_engine.py
import asyncio
from backend.services.llm_engine import parse_query

async def main():
    result = await parse_query("veg north indian food under 200 rupees near Malviya Nagar")
    print(result)

asyncio.run(main())