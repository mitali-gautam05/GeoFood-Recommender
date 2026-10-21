"""
add_diet_flag.py  --  run inside backend/:  python add_diet_flag.py

The dataset has no veg / non-veg column, so this DERIVES one from the
restaurant name and food_type. It is a heuristic, not menu data.

  veg     = confident pure-veg
  nonveg  = name or food_type mentions a non-veg item
  mixed   = everything else (could serve both)

NOTE: food_type is NOT comma-separated; tags are glued together
("dessertsice cream", "juicesbeveragesdesserts"), so we never split it.

Writes a NEW file (restaurants_diet.parquet); the original is untouched.
"""
import re
from pathlib import Path

import pandas as pd

BASE = Path(__file__).resolve().parent
SRC = BASE / "model_artifacts" / "restaurants.parquet"
DST = BASE / "model_artifacts" / "restaurants_diet.parquet"

NAME_COL = "name"
CUISINE_COL = "food_type"

# ---- NON-VEG ---------------------------------------------------------------
# in the NAME: whole-word match
NONVEG_NAME_WORDS = [
    "chicken", "mutton", "lamb", "fish", "prawn", "prawns", "seafood", "crab",
    "egg", "eggs", "kebab", "kebabs", "kabab", "kababs", "kabob", "keema",
    "nihari", "haleem", "shawarma", "beef", "pork", "bacon", "ham", "sausage",
    "steak", "steakhouse", "meat", "kfc", "non veg", "nonveg", "non-veg",
]
NONVEG_NAME_RE = re.compile(
    r"\b(" + "|".join(map(re.escape, NONVEG_NAME_WORDS)) + r")\b", re.I)

# in food_type: SUBSTRING match (tags are glued together, \b would miss them)
NONVEG_FT_RE = re.compile(
    r"chicken|mutton|seafood|kebab|kabab|shawarma|non ?veg|steak", re.I)

# ---- VEG -------------------------------------------------------------------
# explicit veg wording in the NAME
VEG_NAME_RE = re.compile(
    r"(?<!non )(?<!non-)(?<!non)\b(pure veg|pure-veg|vegetarian|veg only|jain|"
    r"sattvic|shuddh|vegan|veggie|veg)\b", re.I)

# softer name hints: only trusted if food_type has no ambiguous cuisines
SOFT_VEG_NAME_RE = re.compile(
    r"\b(sweets|mithai|halwai|ice ?cream|juice|chaat|dosa|idli|udupi)\b", re.I)
AMBIGUOUS_FT_RE = re.compile(
    r"biryani|mughlai|chinese|pizza|burger|italian|continental|grill|roll|momo|"
    r"thai|japanese|asian|goan|bengali|kerala|andhra|hyderabadi|bar", re.I)

# food_type made ONLY of these words -> veg. (bakery deliberately NOT here:
# egg cakes / chicken puffs are common)
VEG_ONLY_WORDS = sorted(
    ["ice cream", "desserts", "dessert", "beverages", "beverage", "juices",
     "juice", "shakes", "shake", "sweets", "mithai", "chaat", "gujarati",
     "jain", "tea"],
    key=len, reverse=True)
VEG_ONLY_RE = re.compile("|".join(map(re.escape, VEG_ONLY_WORDS)), re.I)


def food_type_is_veg_only(ft: str) -> bool:
    ft = ft.strip()
    if not ft:
        return False
    return VEG_ONLY_RE.sub(" ", ft).strip() == ""


def classify(name, food_type):
    name = str(name or "")
    ft = str(food_type or "")

    has_nonveg = bool(NONVEG_NAME_RE.search(name) or NONVEG_FT_RE.search(ft))
    explicit_veg = bool(VEG_NAME_RE.search(name))

    if has_nonveg and explicit_veg:
        return "mixed"                      # conflicting signals -> don't guess
    if has_nonveg:
        return "nonveg"
    if explicit_veg:
        return "veg"
    if food_type_is_veg_only(ft):
        return "veg"
    if SOFT_VEG_NAME_RE.search(name) and not AMBIGUOUS_FT_RE.search(ft):
        return "veg"
    return "mixed"


def main():
    df = pd.read_parquet(SRC)
    print("Columns:", df.columns.tolist())
    print("\nfood_type vs food_type_display (check separators):")
    print(df[[CUISINE_COL, "food_type_display"]].head(8).to_string(index=False))

    df["diet"] = [classify(n, c) for n, c in zip(df[NAME_COL], df[CUISINE_COL])]

    print("\nDiet distribution:")
    counts = df["diet"].value_counts()
    print(pd.DataFrame({"count": counts,
                        "percent": (counts / len(df) * 100).round(1)}))

    for label in ["veg", "nonveg", "mixed"]:
        sub = df[df["diet"] == label]
        print(f"\n--- 20 random '{label}' samples ---")
        if len(sub):
            print(sub[[NAME_COL, CUISINE_COL]]
                  .sample(min(20, len(sub)), random_state=7)
                  .to_string(index=False))

    df.to_parquet(DST, index=False)
    print(f"\nSaved -> {DST}")


if __name__ == "__main__":
    main()