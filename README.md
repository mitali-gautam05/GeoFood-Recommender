# GeoTaste AI

**An AI-powered food recommendation app that learns what you like, knows where you are, and lets you simply ask for what you're craving.**

GeoTaste AI recommends restaurants from a dataset of **33,707 restaurants across 98 Indian cities**. It combines a multi-signal scoring engine, semantic search over restaurant embeddings, an LLM-powered conversational assistant, GPS and weather awareness, a dietary preference filter, and a gamified "food passport" that rewards trying new cuisines.

Built with **Flutter** (mobile + web) and **FastAPI**.

---

## Features

**Recommendations**
- **Multi-signal ranking** that blends text similarity, rating, popularity, budget fit, your taste history, time of day and distance (see [How ranking works](#how-ranking-works)).
- **Mood, weather and time-of-day awareness**: pick a mood (Party, Comfort, Adventure, Spicy, Healthy, Sweet, Date), and the app also reacts to live weather and the current meal slot.
- **Anti-repeat**: cuisines you tried in the last 7 days are ranked lower so suggestions stay fresh.
- **Dietary preference**: Any / Pure Veg / Non-veg, applied in the backend ([details](#dietary-preference-veg--non-veg)).
- **Nearest-city fallback**: if your city isn't in the dataset, the app finds the closest one using the Haversine formula and tells you so.
- **Explainable results**: every card says *why* it was recommended ("Highly rated · Fits your budget · Matches your craving").

**Conversational search ("Ask GeoTaste")**
- Type naturally, for example *"cheap north indian near Malviya Nagar under 200"*. An LLM turns it into structured filters plus a cleaned semantic query.
- Follow-ups work ("cheaper option?", "something different"), because the conversation is kept in a short-lived session.
- Small talk (hello, thanks, help) is handled without running a search.

**Location and notifications**
- GPS-based **"nearby" banner and notification** for places within 5 km, with a "Not hungry" pause.

**Gamification**
- XP, levels, daily streaks, badges, a **cuisine passport**, weekly challenges and a leaderboard.

**Polish**
- Light and dark themes, onboarding, restaurant detail pages, saved places, taste profile and progress screens, and cuisine photos on every card.

---

## Tech stack

| Layer | Technology |
|---|---|
| Mobile / web app | Flutter, Provider (state), SharedPreferences, Geolocator, local notifications |
| API | FastAPI, Uvicorn, Pydantic, SQLAlchemy, JWT auth |
| Ranking | pandas, scikit-learn (TF-IDF), SciPy, fuzzywuzzy |
| Semantic search | `multilingual-e5-large` embeddings via fastembed (ONNX) + ChromaDB |
| LLM | Groq: `openai/gpt-oss-20b` (query parsing), `openai/gpt-oss-120b` (explanations) |
| Conversation flow | LangGraph |
| Storage | PostgreSQL (users, clicks, passport, challenges, cache), Redis (cache, sessions, cuisine photos) |
| Images | Unsplash (prefetched once, served from Redis) |

---

## Architecture

```
Flutter app (Provider)
      │  HTTP / JSON
      ▼
FastAPI  ──────────────────────────────────────────────┐
  │                                                     │
  ├─ /recommend ─▶ recommender.py                       ├─ PostgreSQL
  │                 ├─ TF-IDF similarity                │   users · clicks · passport
  │                 ├─ semantic scores (ChromaDB) ◀──── │   challenges · cached results
  │                 ├─ rating / budget / time / distance│
  │                 └─ mood · weather · diet · anti-repeat
  │                                                     ├─ Redis
  └─ /converse ──▶ LangGraph                            │   response cache · chat sessions
                    router → parse → retrieve → explain │   cuisine photo pools
                       (Groq LLM)   (retry if empty)    │
                                                        └─ ChromaDB (restaurant embeddings)
```

**Caching** has three layers: a Redis lookup first (30-minute TTL), then PostgreSQL, then the full computation. The cache key includes city, query, budget, mood, time slot, weather tags and (only when set) the diet.

---

## How ranking works

Each candidate restaurant gets a score from these signals:

| Signal | Weight | Notes |
|---|---|---|
| Similarity to your query | 0.25 | Half TF-IDF, half semantic (ChromaDB) |
| Rating | 0.18 | Normalised within the candidate set |
| Popularity | 0.12 | |
| Budget fit | 0.12 | Gaussian curve around your budget |
| Your taste history | 0.08 | From your past clicks |
| Time-of-day fit | 0.05 | Breakfast, snack, lunch, dinner, late night |
| Distance | 0.05 | Haversine, from your GPS position |
| Mood match | +0.10 | Only when a mood is selected |
| Weather match | +0.05 | Only when the weather suggests it |
| Recently eaten | −0.30 | Cuisines from the last 7 days |

The final score is clipped to 0–1, then a diversity pass limits how many results share the same cuisine.

---

## Conversational search

`POST /api/v1/converse` runs a **LangGraph** state machine:

```
START → router ─┬─ smalltalk → END
                ├─ click → END
                └─ search → parse → retrieve ─┬─ (empty, retries left) → widen filters → retrieve
                                              └─ explain → finalize → END
```

- **Hybrid retrieval**: city and budget are hard ChromaDB metadata filters; cuisine is folded into the semantic query and used for a light boost (the cuisine field is a messy comma-joined string, so exact filtering would be unreliable).
- **Progressive relaxation**: if a strict filter combination returns nothing, the filters are widened step by step and the response says what was relaxed.
- **Fail-soft LLM calls**: rate-limit errors are retried with exponential backoff.

`POST /api/v1/chat` is the older stateless, single-shot version of the same idea.

---

## Dietary preference (Veg / Non-veg)

Choose **Any** (default), **Pure Veg** or **Non-veg** from the Discover or Explore screen. The choice is saved on the device.

| Choice | Returns |
|---|---|
| **Any** | Everything, no filter |
| **Pure Veg** | Only places labelled `veg` |
| **Non-veg** | Places labelled `nonveg` **or** `mixed` |

- The filter runs **in the backend**, before scoring, so ranking and the top-N list are computed on the filtered set.
- The diet joins the cache key only when it is set, so existing "Any" cache entries stay valid.
- Input is normalised (`" NONVEG "` and `"Veg"` both work); anything unrecognised means "Any".
- Cards show a green dot for veg and a red dot for non-veg. **Mixed places deliberately show no dot**, because we don't know what they serve.
- If nothing matches (for example, no pure-veg place in a small city), the app shows an empty state with a **Show all places** button.

**Where the labels come from.** The source dataset has no veg / non-veg column, so `backend/add_diet_flag.py` **derives** one from each restaurant's name and cuisine tags. It is a heuristic, not menu data. Distribution: **mixed 87.6%, veg 8.3%, nonveg 4.1%**. The heuristic favours precision over recall, because showing a veg user a non-veg place is the worse mistake.

If `restaurants.parquet` has no `diet` column, every place is treated as `mixed` and Pure Veg returns nothing (fail-safe).

> **Not yet supported:** the chat assistant (`/converse`) does not apply the diet preference yet. See [Known limitations](#known-limitations).

---

## API overview

Interactive docs are at **`/docs`** (Swagger) once the backend is running. All routes are prefixed with `/api/v1`.

| Area | Endpoint | Purpose |
|---|---|---|
| Auth | `POST /auth/register`, `POST /auth/login`, `GET /auth/me`, `PATCH /auth/me/city` | Accounts and JWT login |
| Recommend | `POST /recommend` | Ranked recommendations (supports `diet`, `mood`, `time_slot`, `weather_tags`, `avoid_cuisines`) |
| Recommend | `POST /click`, `POST /not-hungry` | Log a tap on a cuisine; pause suggestions |
| Cities | `GET /cities`, `GET /cities/search` | City list and autocomplete |
| Places | `GET /places/nearby`, `GET /places/recommend` | Distance-based place lookups |
| Chat | `POST /converse`, `POST /chat`, `POST /explain` | Conversational search and explanations |
| Social | `POST /passport/sync`, `GET /passport`, `GET /leaderboard`, `POST /challenge/complete` | Passport, leaderboard, challenges |
| Health | `GET /health` | Liveness check |

Example:

```http
POST /api/v1/recommend
Content-Type: application/json

{
  "username": "test_user",
  "query": "something tasty",
  "city": "Bangalore",
  "budget": 500,
  "min_rating": 3.5,
  "top_n": 10,
  "diet": "veg"
}
```

---

## Project structure

```
backend/
  main.py                  FastAPI app and router wiring
  config.py                Settings read from backend/.env
  add_diet_flag.py         Builds the veg / nonveg / mixed label
  add_coordinates.py       Adds lat/lng to the dataset
  clear_recommend_cache.py Clears ONLY recommendation caches (safe)
  routes/                  auth, recommender, chat, converse, places, social
  services/
    recommender.py         Scoring engine
    rag_engine.py          Hybrid retrieval over ChromaDB
    llm_engine.py          Groq: parse, follow-up, explain
    chat_graph.py          LangGraph conversation flow
    cache.py               Redis + PostgreSQL cache
    image_service.py       Cuisine photos from Redis
    session_store.py       Chat history (30-minute idle reset)
  models/ schemas/         SQLAlchemy models and Pydantic schemas
  rag/                     Index building, photo prefetch, evaluation and test scripts
frontend/
  lib/
    providers/             places, favourites, gamification, theme
    screens/               home, explore, chat, favourites, taste, progress, profile, auth, onboarding
    services/              API client, location, notifications, weather
    widgets/               diet selector, streak banner, city autocomplete, cards
```

---

## Getting started

### Prerequisites

- Python 3.10+
- PostgreSQL
- Redis
- Flutter 3.22+ (the diet selector uses `WidgetState`; on older Flutter, rename it to `MaterialState`)
- A [Groq](https://console.groq.com) API key
- Optional: an [Unsplash](https://unsplash.com/developers) access key (for cuisine photos) and an [OpenWeatherMap](https://openweathermap.org/api) key (for weather suggestions)

### 1. Backend

```bash
cd backend
python -m venv .venv
# Windows: .venv\Scripts\activate      macOS/Linux: source .venv/bin/activate
pip install -r requirements.txt
```

Create `backend/.env`:

```env
DATABASE_URL=postgresql://user:password@localhost:5432/geotaste
SECRET_KEY=change-me
REDIS_URL=redis://localhost:6379/0
GROQ_API_KEY=your-groq-key
UNSPLASH_ACCESS_KEY=your-unsplash-key   # optional
```

### 2. Data and model files

The ranking and search artifacts live in `backend/model_artifacts/` and are not part of the code:

| File | Purpose |
|---|---|
| `restaurants.parquet` | The restaurant dataset (needs a `diet` column, see below) |
| `tfidf_vectorizer.pkl`, `popularity_scaler.pkl` | Fitted ranking artifacts |
| `rag/serialized_restaurants.parquet` | Restaurants converted to text for embedding |
| `rag/chroma_store/` | ChromaDB vector index |

Build the derived pieces from `backend/`:

```bash
python add_coordinates.py          # lat/lng per restaurant (only if the dataset has none)
python add_diet_flag.py            # writes model_artifacts/restaurants_diet.parquet
```

Check that `restaurants_diet.parquet` has the same row count, name order and index as `restaurants.parquet`, then swap it in:

```bash
cd model_artifacts
cp restaurants.parquet restaurants_backup.parquet
cp restaurants_diet.parquet restaurants.parquet
```

> The row order must not change: ChromaDB IDs are built from the original row index, so a reordered file would silently attach semantic scores to the wrong restaurants.

Then build the semantic index and the cuisine photos:

```bash
python rag/serialize.py            # restaurants → text
python rag/embed_index.py          # embeddings + ChromaDB (one-time, offline)
python rag/fix_metadata_types.py   # one-time: store price/rating as numbers for budget filtering
python rag/prefetch_cuisine_images.py   # Unsplash photo pools into Redis (needs UNSPLASH_ACCESS_KEY)
```

The Unsplash demo key allows about 50 requests per hour; the script skips tags that are already cached, so you can simply re-run it later.

### 3. Run the backend

```bash
uvicorn main:app --reload
```

Open `http://localhost:8000/docs`. Tables are created automatically on startup.

### 4. Run the app

```bash
cd frontend
flutter pub get
flutter run -d web-server --web-port=5000
```

Open `http://localhost:5000` in your **normal** Chrome window. (`flutter run -d chrome` uses a temporary profile, which wipes saved settings such as your diet choice on every run.)

The app talks to `http://localhost:8000` on web and `http://10.0.2.2:8000` on the Android emulator; change the base URL in `frontend/lib/services/api_client.dart` if needed. To enable weather suggestions, set your own OpenWeatherMap key in `frontend/lib/services/weather_recommendation_service.dart`.

---

## Maintenance tips

- **Clear only the recommendation cache** with `python clear_recommend_cache.py` (add `--dry-run` to preview). It removes the `recommend:*` keys and cached PostgreSQL rows and leaves the cuisine photos alone.
- **Don't run `FLUSHDB` / `FLUSHALL` on the Redis you use for this app.** Cuisine photo pools are stored there with no expiry, so a flush deletes them and every card loses its image until you re-run `rag/prefetch_cuisine_images.py`.
- Recommendations are cached for 30 minutes. If you change ranking or data and don't see an effect, clear the cache first.

---

## Evaluation and tests

The `backend/rag/` folder holds evaluation and flow scripts:

- `eval_queries.py` and `eval_parse_accuracy.py`: measure how accurately the LLM turns 20 hand-labelled queries into structured filters (per-field exact match).
- `test_retrieval.py`, `test_hybrid_recommend.py`, `test_llm_engine.py`: retrieval and LLM checks.
- `test_click_flow.py`, `test_followup_flow.py`, `test_retry_flow.py`, `test_smalltalk.py`: conversation-flow checks.

Run them from `backend/`, for example `python rag/eval_parse_accuracy.py` (needs a valid `GROQ_API_KEY`).

---

## Known limitations

- **Diet labels are heuristic.** They are inferred from names and cuisine tags, not menus, so some genuinely veg places are labelled `mixed` or `nonveg` and won't appear under Pure Veg.
- **Chat does not apply the diet preference yet.** The chat's parsed `dietary` value only influences the semantic query text; it is not an enforced filter. Planned fix: carry the diet into the chat session state and add an `is_veg` field to the vector index metadata.
- **Semantic ranking is not diet-aware.** The semantic retrieval takes its top 200 matches before the diet filter, so in large cities the Pure Veg list is ranked mostly by TF-IDF. The filter stays correct; only ranking quality drops.
- **Restaurant coordinates are approximate.** `add_coordinates.py` places each restaurant near its city centre with a small random offset (about ±2 km), so distance scoring and the "nearby" banner are indicative, not exact.
- **Cuisine photos are stock images per cuisine tag**, not photos of the actual restaurant, so a photo can occasionally look off for a niche cuisine.
- **Rapid toggling of the diet selector** could let an older response overwrite a newer one; a latest-request-wins guard is not implemented.

---

## Roadmap

- Enforce the diet preference in the conversational assistant.
- Replace the heuristic diet labels with menu-derived data or a small classifier validated on a hand-checked sample.
- Real restaurant coordinates and photos.
- Move API keys out of source code into build-time configuration.

---
