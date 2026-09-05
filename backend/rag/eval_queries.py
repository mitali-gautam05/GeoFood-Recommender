"""
Labeled eval set for parse_query() in llm_engine.py.

20 hand-written queries with the correct expected JSON output. Used by
eval_parse_accuracy.py to compute field-level exact-match accuracy --
turns "it seemed to work" into an actual measured number.

Notes on labeling:
- cleaned_query is NOT scored for exact match (it's free text, there's no
  single "correct" rewrite) -- only checked for being non-empty.
- budget_max: labeled with the exact number if stated, or the same
  reasonable estimate the LLM is instructed to use for vague words
  ("cheap" -> 200, "affordable" -> 300) so scoring isn't unfairly strict.
- Mix of English, Hinglish, and queries with no filters at all (to check
  the model doesn't hallucinate filters that aren't there).
"""

EVAL_QUERIES = [
    {
        "query": "affordable biryani in Mangalore",
        "expected": {"cuisine": "biryani", "budget_max": 300, "location_hint": "Mangalore", "dietary": None},
    },
    {
        "query": "sasta biryani nearby",
        # "nearby" is a genuine location signal -- either None or "nearby" is acceptable;
        # scored loosely here since this is a wording judgment call, not a hard bug.
        "expected": {"cuisine": "biryani", "budget_max": 200, "location_hint": "nearby", "dietary": None},
    },
    {
        "query": "vegan restaurants under 250 rupees",
        "expected": {"cuisine": None, "budget_max": 250, "location_hint": None, "dietary": "vegan"},
    },
    {
        "query": "cheap north indian food",
        "expected": {"cuisine": "north indian", "budget_max": 200, "location_hint": None, "dietary": None},
    },
    {
        "query": "best pizza place",
        "expected": {"cuisine": "pizza", "budget_max": None, "location_hint": None, "dietary": None},
    },
    {
        "query": "jain thali under 150",
        "expected": {"cuisine": "thali", "budget_max": 150, "location_hint": None, "dietary": "jain"},
    },
    {
        "query": "kuch bhi accha khana hai",
        "expected": {"cuisine": None, "budget_max": None, "location_hint": None, "dietary": None},
    },
    {
        "query": "south indian breakfast near malviya nagar",
        "expected": {"cuisine": "south indian", "budget_max": None, "location_hint": "malviya nagar", "dietary": None},
    },
    {
        "query": "high end continental dining",
        "expected": {"cuisine": "continental", "budget_max": None, "location_hint": None, "dietary": None},
    },
    {
        "query": "gluten free options under 400",
        "expected": {"cuisine": None, "budget_max": 400, "location_hint": None, "dietary": "gluten free"},
    },
    {
        "query": "chinese food for 100 rupees",
        "expected": {"cuisine": "chinese", "budget_max": 100, "location_hint": None, "dietary": None},
    },
    {
        "query": "sasta khana",
        "expected": {"cuisine": None, "budget_max": 200, "location_hint": None, "dietary": None},
    },
    {
        "query": "expensive fine dining experience",
        "expected": {"cuisine": None, "budget_max": None, "location_hint": None, "dietary": None},
    },
    {
        "query": "vegetarian biryani near college under 200",
        "expected": {"cuisine": "biryani", "budget_max": 200, "location_hint": "near college", "dietary": "vegetarian"},
    },
    {
        "query": "mujhe kuch spicy chahiye",
        "expected": {"cuisine": None, "budget_max": None, "location_hint": None, "dietary": None},
    },
    {
        "query": "korean food",
        "expected": {"cuisine": "korean", "budget_max": None, "location_hint": None, "dietary": None},
    },
    {
        "query": "budget friendly dessert shop",
        "expected": {"cuisine": "dessert", "budget_max": 200, "location_hint": None, "dietary": None},
    },
    {
        "query": "500 rupees ke andar family restaurant",
        "expected": {"cuisine": None, "budget_max": 500, "location_hint": None, "dietary": None},
    },
    {
        "query": "vegan and affordable italian",
        "expected": {"cuisine": "italian", "budget_max": 300, "location_hint": None, "dietary": "vegan"},
    },
    {
        "query": "andhra style food in kota",
        "expected": {"cuisine": "andhra", "budget_max": None, "location_hint": "kota", "dietary": None},
    },
    # -- Generalization check below: these use HIGH-budget words that are
    # NOT in the prompt's example list ("expensive", "high end", "fine
    # dining", "premium", "luxury"). If the model still returns null
    # for budget_max here, that's evidence it's following the pattern
    # (vague high-budget vibe -> null), not just matching the literal
    # example words in the prompt.
    {
        "query": "posh 5-star restaurant",
        "expected": {"cuisine": None, "budget_max": None, "location_hint": None, "dietary": None},
    },
    {
        "query": "upscale rooftop dining",
        "expected": {"cuisine": None, "budget_max": None, "location_hint": None, "dietary": None},
    },
]