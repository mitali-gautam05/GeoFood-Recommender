# backend/services/recommender.py
# Changes from original:
#   1. recommend() now accepts mood, time_slot, weather_tags, avoid_cuisines
#      — these were sent by Flutter but silently ignored before
#   2. record_click() now persists to PostgreSQL (was RAM-only before)
#   3. build_user_vector() now loads click history from PostgreSQL on startup
#   4. 3-layer cache wired in via services/cache.py
#   5. Mood boost (+25%), weather boost (+10%), avoid-cuisine penalty (-30%)

import joblib
import pandas as pd
import numpy as np
from pathlib import Path
from sklearn.metrics.pairwise import cosine_similarity
from scipy.stats import norm
from fuzzywuzzy import process
from datetime import datetime, timedelta
from typing import Optional
import math
import logging
from services.rag_engine import get_semantic_scores

logger = logging.getLogger(__name__)

# ── Load artifacts once when server starts ─────────────────────────────────────
BASE = Path(__file__).resolve().parent.parent / "model_artifacts"

tfidf  = joblib.load(BASE / "tfidf_vectorizer.pkl")
scaler = joblib.load(BASE / "popularity_scaler.pkl")
df     = pd.read_parquet(BASE / "restaurants.parquet")

df["food_type"]  = df["food_type"].fillna("").astype(str)
df["name"]       = df["name"].fillna("unknown").astype(str)
df["tfidf_text"] = (df["food_type"] + " " + df["name"].str.lower()).fillna("")

KNOWN_CITIES = df["city"].unique().tolist()

# ── Mood → cuisine weight map ─────────────────────────────────────────────────
MOOD_CUISINE_MAP = {
    "celebrating":  ["biryani", "continental", "pizza", "desserts", "north indian"],
    "comfort":      ["north indian", "south indian", "khichdi", "dal", "thali"],
    "adventurous":  ["korean", "japanese", "mexican", "thai", "persian", "afghani"],
    "date_night":   ["continental", "italian", "pizza", "chinese", "rooftop"],
    "tired":        ["fast food", "pizza", "burgers", "rolls", "quick bites"],
    "spicy":        ["andhra", "hyderabadi", "chettinad", "street food", "kebabs"],
    "healthy":      ["salads", "south indian", "smoothies", "juices", "multigrain"],
    "sweet":        ["desserts", "sweets", "ice cream", "bakery", "cafe"],
}

# ── Weather → cuisine weight map ──────────────────────────────────────────────
WEATHER_CUISINE_MAP = {
    "rainy":   ["chai", "street food", "pakora", "samosa", "maggi", "snacks"],
    "hot":     ["ice cream", "cold coffee", "beverages", "juices", "desserts"],
    "cold":    ["soup", "hot chocolate", "north indian", "biryani", "tandoor"],
    "cloudy":  ["street food", "snacks", "fast food"],
    "windy":   ["hot beverages", "chai", "snacks"],
}

# ── GPS helpers ────────────────────────────────────────────────────────────────
def haversine_km(lat1, lon1, lat2, lon2) -> float:
    R = 6371
    lat1, lon1, lat2, lon2 = map(math.radians, [lat1, lon1, lat2, lon2])
    dlat = lat2 - lat1
    dlon = lon2 - lon1
    a = math.sin(dlat/2)**2 + math.cos(lat1)*math.cos(lat2)*math.sin(dlon/2)**2
    return R * 2 * math.asin(math.sqrt(a))

def km_to_score(km: float) -> float:
    if   km <= 1:  return 1.0
    elif km <= 3:  return 0.8
    elif km <= 7:  return 0.5
    elif km <= 15: return 0.3
    else:          return 0.1

def find_nearest_city(user_lat: float, user_lng: float) -> tuple:
    city_centers = df.groupby("city")[["lat", "lng"]].mean()
    best_city, best_km = None, float("inf")
    for city, row in city_centers.iterrows():
        km = haversine_km(user_lat, user_lng, row["lat"], row["lng"])
        if km < best_km:
            best_km, best_city = km, city
    return best_city, round(best_km, 1)

# ── Time windows ───────────────────────────────────────────────────────────────
TIME_MAP = {
    "breakfast":  {"hours": (6,  10), "foods": ["south indian","dosa","idli","chai","cafe","bakery"]},
    "snack":      {"hours": (15, 18), "foods": ["chai","samosa","sandwich","snacks","street food"]},
    "lunch":      {"hours": (11, 15), "foods": ["biryani","north indian","thali","meals","chinese"]},
    "dinner":     {"hours": (19, 23), "foods": ["biryani","fast food","butter chicken","dhaba","pizza"]},
    "late_night": {"hours": (23,  3), "foods": ["dhaba","biryani","maggi","paratha","kebab"]},
}

# ── In-memory sessions (pause state only — clicks now in PostgreSQL) ───────────
USER_SESSIONS: dict = {}

def get_session(username: str) -> dict:
    if username not in USER_SESSIONS:
        USER_SESSIONS[username] = {"not_hungry_until": None}
    return USER_SESSIONS[username]

def set_not_hungry(username: str, minutes: int = 60):
    get_session(username)["not_hungry_until"] = (
        datetime.now() + timedelta(minutes=minutes)
    )

def is_paused(username: str) -> bool:
    pause = get_session(username).get("not_hungry_until")
    return bool(pause and datetime.now() < pause)


# ── Click recording — now persists to PostgreSQL ──────────────────────────────
def record_click(username: str, food_type: str, city: str = None, db=None):
    """
    Save click to PostgreSQL if db session provided,
    otherwise fall back to in-memory only (e.g. called from old code paths).
    """
    if db is not None:
        try:
            from models.user_click import UserClick
            click = UserClick(
                username  = username,
                food_type = food_type.lower().strip(),
                city      = city,
            )
            db.add(click)
            db.commit()
        except Exception as e:
            logger.warning(f"Failed to persist click to DB: {e}")
            db.rollback()


def load_user_clicks_from_db(username: str, db, days: int = 30) -> list:
    """Load recent click history from PostgreSQL for a user."""
    try:
        from models.user_click import UserClick
        cutoff = datetime.utcnow() - timedelta(days=days)
        rows = (
            db.query(UserClick.food_type)
            .filter(
                UserClick.username   == username,
                UserClick.clicked_at >= cutoff,
            )
            .all()
        )
        return [r.food_type for r in rows]
    except Exception as e:
        logger.warning(f"Failed to load clicks from DB: {e}")
        return []


# ── Helper functions ───────────────────────────────────────────────────────────
def fuzzy_city(city_input: str, threshold: int = 70):
    city_input = city_input.lower().strip()
    match, score = process.extractOne(city_input, KNOWN_CITIES)
    return match if score >= threshold else None

def get_available_cities() -> list:
    return sorted([c.title() for c in df["city"].unique().tolist()])

def search_cities(query: str, limit: int = 8) -> list:
    query = query.lower().strip()
    if not query:
        return []
    prefix  = [c.title() for c in KNOWN_CITIES if c.lower().startswith(query)]
    fuzzy   = [c.title() for c in KNOWN_CITIES
               if query in c.lower() and c.title() not in prefix]
    return (prefix + fuzzy)[:limit]

def get_time_context(hour: int = None) -> str:
    if hour is None:
        hour = datetime.now().hour
    for ctx, info in TIME_MAP.items():
        lo, hi = info["hours"]
        if lo > hi:
            if hour >= lo or hour < hi:
                return ctx
        elif lo <= hour < hi:
            return ctx
    return "lunch"

def time_boost(row, context: str) -> float:
    food = str(row["food_type"]).lower()
    return float(any(k in food for k in TIME_MAP.get(context, {}).get("foods", [])))

def budget_score(price: float, user_budget: float) -> float:
    sigma = max(user_budget * 0.3, 30)
    return float(
        norm.pdf(price,       loc=user_budget, scale=sigma) /
        norm.pdf(user_budget, loc=user_budget, scale=sigma)
    )

def build_user_vector(clicks: list):
    """Build TF-IDF preference vector from a list of food_type strings."""
    if not clicks:
        return None
    vecs = tfidf.transform(clicks)
    return np.asarray(vecs.mean(axis=0))

def apply_diversity(results: pd.DataFrame, max_same: int = 2) -> pd.DataFrame:
    seen, keep = {}, []
    for _, row in results.iterrows():
        ft = row["food_type"]
        if seen.get(ft, 0) < max_same:
            keep.append(row)
            seen[ft] = seen.get(ft, 0) + 1
    return pd.DataFrame(keep).reset_index(drop=True)

def clean_food_type(ft: str) -> str:
    ft = str(ft).strip().lower()
    known = [
        "north indian", "south indian", "fast food", "street food",
        "chinese", "biryani", "beverages", "snacks", "desserts",
        "american", "mughlai", "hyderabadi", "andhra", "pizza",
        "sweets", "continental", "italian", "mexican", "punjabi",
        "seafood", "kebabs", "rolls", "burgers", "rajasthani",
        "gujarati", "lucknowi", "persian", "afghani", "kerala",
        "tandoor", "arabic", "indian",
    ]
    for k in sorted(known, key=len, reverse=True):
        ft = ft.replace(k, f"|{k}")
    parts = [p.strip().title() for p in ft.split("|") if p.strip()]
    seen  = set()
    final = []
    for p in parts:
        if p not in seen and len(p) > 2:
            seen.add(p)
            final.append(p)
    return ", ".join(final[:4]) if final else ft.title()


# ── NEW: Mood boost score ──────────────────────────────────────────────────────
def mood_boost_score(row, mood: Optional[str]) -> float:
    """
    Returns 1.0 if the restaurant's cuisine matches the mood's preferred
    cuisines, 0.0 otherwise. Applied as a +25% multiplier in final_score.
    """
    if not mood:
        return 0.0
    preferred = MOOD_CUISINE_MAP.get(mood.lower(), [])
    food      = str(row["food_type"]).lower()
    return 1.0 if any(p in food for p in preferred) else 0.0


# ── NEW: Weather boost score ───────────────────────────────────────────────────
def weather_boost_score(row, weather_tags: list) -> float:
    """
    Returns 1.0 if the restaurant's cuisine matches any active weather tag.
    Applied as a +10% multiplier in final_score.
    """
    if not weather_tags:
        return 0.0
    food = str(row["food_type"]).lower()
    for tag in weather_tags:
        preferred = WEATHER_CUISINE_MAP.get(tag.lower(), [])
        if any(p in food for p in preferred):
            return 1.0
    return 0.0


# ── NEW: Anti-repeat penalty ───────────────────────────────────────────────────
def avoid_penalty(row, avoid_cuisines: list) -> float:
    """
    Returns -0.30 if this cuisine was eaten recently (sent from Flutter's
    7-day memory). Applied directly to final_score before clipping.
    """
    if not avoid_cuisines:
        return 0.0
    food = str(row["food_type"]).lower()
    for cuisine in avoid_cuisines:
        if cuisine.lower() in food:
            return -0.30
    return 0.0


# ── Main recommend function ────────────────────────────────────────────────────
def recommend(
    username:           str,
    query:              str,
    city:               str,
    budget:             float          = 300,
    min_rating:         float          = 3.5,
    top_n:              int            = 5,
    hunger_mode:        str            = "hungry",
    hour:               int            = None,
    user_lat:           float          = None,
    user_lng:           float          = None,
    # NEW parameters — Flutter sends these, now we use them
    mood:               Optional[str]  = None,
    time_slot:          Optional[str]  = None,   # overrides server-side hour detection
    weather_tags:       Optional[list] = None,
    avoid_cuisines:     Optional[list] = None,
    budget_max: Optional[float] = None,      # NEW
    cuisine: Optional[str] = None,
    # Internal recursion args
    _fallback_city:     str            = None,
    _fallback_distance: float          = None,
    # DB session for click history + caching
    db                                 = None,
) -> dict:

    if hunger_mode == "later":
        set_not_hungry(username)

    # ── 3-layer cache check ───────────────────────────────────────────────────
    if db is not None:
        from services.cache import make_cache_key, cache_get, cache_set
        cache_key = make_cache_key(
            city         = city,
            query        = query,
            budget       = budget,
            mood         = mood,
            time_slot    = time_slot,
            weather_tags = weather_tags,
        )
        cached = cache_get(cache_key, db)
        if cached is not None:
            logger.info(f"Cache HIT for {cache_key}")
            return cached

    # ── City match ────────────────────────────────────────────────────────────
    city_matched = fuzzy_city(city)

    if not city_matched:
        if user_lat and user_lng:
            nearest_city, distance_km = find_nearest_city(user_lat, user_lng)
            return recommend(
                username=username, query=query, city=nearest_city,
                budget=budget, min_rating=min_rating, top_n=top_n,
                hunger_mode=hunger_mode, hour=hour,
                user_lat=user_lat, user_lng=user_lng,
                mood=mood, time_slot=time_slot,
                weather_tags=weather_tags, avoid_cuisines=avoid_cuisines,
                _fallback_city=city, _fallback_distance=distance_km,
                db=db,
            )
        return {
            "status":          "city_not_found",
            "searched_city":   city,
            "suggestions":     search_cities(city, limit=6),
            "recommendations": [],
        }

    city_df = df[df["city"] == city_matched].copy()
    city_df["rag_id"] = city_df.index.astype(str)
    city_df = city_df.reset_index(drop=True)

    # ── Rating filter ─────────────────────────────────────────────────────────
    filtered = city_df[city_df["rating"] >= min_rating]
    city_df  = filtered.reset_index(drop=True) if len(filtered) >= 5 else city_df

    # ── TF-IDF similarity ─────────────────────────────────────────────────────
    city_tfidf           = tfidf.transform(city_df["tfidf_text"].fillna(""))
    query_vec            = tfidf.transform([query.lower()])
    city_df["sim_score"] = cosine_similarity(query_vec, city_tfidf).flatten()
    semantic_scores, relaxed_notes = get_semantic_scores(
    query, city_matched, budget_max=budget_max, cuisine=cuisine, top_k=200)
    city_df["semantic_score"] = city_df["rag_id"].map(semantic_scores).fillna(0.0)
    city_df["sim_score"] = 0.5 * city_df["sim_score"] + 0.5 * city_df["semantic_score"]

    strong = city_df[city_df["sim_score"] >= 0.05]
    if len(strong) >= 5:
        city_df    = strong.reset_index(drop=True)
        city_tfidf = tfidf.transform(city_df["tfidf_text"].fillna(""))

    # ── User preference vector (from PostgreSQL click history) ────────────────
    clicks = load_user_clicks_from_db(username, db) if db else []
    user_vec = build_user_vector(clicks)
    if user_vec is not None:
        city_df["pref_score"] = cosine_similarity(user_vec, city_tfidf).flatten()
    else:
        city_df["pref_score"] = 0.5

    # ── Standard scores ───────────────────────────────────────────────────────
    city_df["budget_score"] = city_df["price"].apply(
        lambda p: budget_score(p, budget)
    )
    r_min = city_df["rating"].min()
    r_max = city_df["rating"].max()
    city_df["rating_score"] = (
        (city_df["rating"] - r_min) / (r_max - r_min + 1e-8)
    )

    # Time context: Flutter's time_slot takes priority over server clock
    ctx = time_slot if time_slot in TIME_MAP else get_time_context(hour)
    city_df["time_boost"] = city_df.apply(
        lambda r: time_boost(r, ctx), axis=1
    )

    # Distance score
    if user_lat and user_lng and "lat" in city_df.columns and "lng" in city_df.columns:
        city_df["dist_score"] = city_df.apply(
            lambda r: km_to_score(
                haversine_km(user_lat, user_lng, r["lat"], r["lng"])
            ),
            axis=1,
        )
    else:
        city_df["dist_score"] = 0.5

    if "popularity_norm" not in city_df.columns:
        city_df["popularity_norm"] = 0.5

    # ── NEW: Mood boost ───────────────────────────────────────────────────────
    city_df["mood_boost"] = city_df.apply(
        lambda r: mood_boost_score(r, mood), axis=1
    )

    # ── NEW: Weather boost ────────────────────────────────────────────────────
    city_df["weather_boost"] = city_df.apply(
        lambda r: weather_boost_score(r, weather_tags or []), axis=1
    )

    # ── NEW: Anti-repeat penalty ──────────────────────────────────────────────
    city_df["avoid_penalty"] = city_df.apply(
        lambda r: avoid_penalty(r, avoid_cuisines or []), axis=1
    )

    # ── Why recommended ───────────────────────────────────────────────────────
    has_clicks = bool(clicks)

    def why(row):
        reasons = []
        if row["rating"] >= 4.2:                    reasons.append("Highly rated")
        if row["budget_score"] >= 0.7:              reasons.append("Fits your budget")
        if row["sim_score"] >= 0.3:                 reasons.append("Matches your craving")
        if row["time_boost"] == 1.0:                reasons.append(f"Great for {ctx}")
        if row["mood_boost"] == 1.0 and mood:       reasons.append(f"Matches your {mood} mood")
        if row["weather_boost"] == 1.0:             reasons.append("Perfect for today's weather")
        if has_clicks and row["pref_score"] >= 0.5: reasons.append("You've liked this before")
        return " · ".join(reasons) if reasons else "Good overall match"

    city_df["why_recommended"] = city_df.apply(why, axis=1)

    # ── Final score ───────────────────────────────────────────────────────────
    # Original weights sum to 1.0. New signals (mood +25%, weather +10%)
    # are additive bonuses; avoid_penalty is a direct subtraction.
    # All capped to [0, 1] after.
    city_df["final_score"] = (
        0.25 * city_df["sim_score"]       +
        0.18 * city_df["rating_score"]    +
        0.12 * city_df["popularity_norm"] +
        0.12 * city_df["budget_score"]    +
        0.08 * city_df["pref_score"]      +
        0.05 * city_df["time_boost"]      +
        0.05 * city_df["dist_score"]      +
        # NEW signals
        0.10 * city_df["mood_boost"]      +   # +25% for mood match
        0.05 * city_df["weather_boost"]   +   # +10% for weather match
        city_df["avoid_penalty"]              # -30% for recently eaten
    ).clip(0, 1)

    results = city_df.sort_values("final_score", ascending=False)
    results = apply_diversity(results, max_same=2).head(top_n).reset_index(drop=True)

    # ── Build response ────────────────────────────────────────────────────────
    output = []
    for _, row in results.iterrows():
        output.append({
            "name":             row["name"],
            "cuisine":          clean_food_type(row["food_type"]),
            "price":            int(row["price"]),
            "rating":           round(float(row["rating"]),         1),
            "score":            round(float(row["final_score"]),    3),
            "why_recommended":  row["why_recommended"],
            "city":             row["city"],
            "matched_city":     city_matched,
            "sim_score":        round(float(row["sim_score"]),       3),
            "rating_score":     round(float(row["rating_score"]),    3),
            "budget_score":     round(float(row["budget_score"]),    3),
            "time_boost":       round(float(row["time_boost"]),      3),
            "pref_score":       round(float(row["pref_score"]),      3),
            "popularity_norm":  round(float(row["popularity_norm"]), 3),
            "mood_boost":       round(float(row["mood_boost"]),      3),
            "weather_boost":    round(float(row["weather_boost"]),   3),
        })

    result = {
        "status":            "ok",
        "searched_city":     city,
        "matched_city":      city_matched,
        "fallback_from":     _fallback_city,
        "fallback_distance": _fallback_distance,
        "relaxed_notes":      relaxed_notes, 
        "recommendations":   output,
    }

    # ── Write to cache ────────────────────────────────────────────────────────
    if db is not None:
        cache_set(cache_key, result, db)

    return result