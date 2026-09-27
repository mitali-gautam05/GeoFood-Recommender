# 🍽️ GeoTaste AI

> **Discover food you'll actually love** — a smart restaurant discovery app powered by a multi-signal ML recommendation engine, a RAG/LLM explainability layer, and a LangGraph-driven conversational agent that learns your taste, reads your mood, and checks the weather before suggesting where to eat.

![FastAPI](https://img.shields.io/badge/FastAPI-005571?style=flat&logo=fastapi)
![Python](https://img.shields.io/badge/Python-3776AB?style=flat&logo=python&logoColor=white)
![PostgreSQL](https://img.shields.io/badge/PostgreSQL-316192?style=flat&logo=postgresql&logoColor=white)
![LangGraph](https://img.shields.io/badge/LangGraph-1C3C3C?style=flat)

---

## What is GeoTaste?

GeoTaste is a **cross-platform food discovery app** (not delivery) that recommends restaurants based on who you are, not just where you are. It combines a 7-signal ML scoring engine with a semantic RAG/LLM layer and a conversational agent, so you can either browse a ranked feed or just *ask* — "something spicy under ₹300 near me" — and get a grounded, explained answer.

**Built with:** Flutter (Android + iOS + Web) · Python FastAPI · PostgreSQL · Redis · TF-IDF + cosine similarity · ChromaDB + fastembed · LangGraph · Groq (Llama)

---

## How the recommendation engine works

The core scoring pipeline blends 7 weighted signals for every restaurant candidate:

```python
final_score = (
  0.25 * sim_score       +  # TF-IDF + semantic (RAG) query match, blended 50/50
  0.18 * rating_score    +  # normalised restaurant rating
  0.12 * popularity_norm +  # popularity signal
  0.12 * budget_score    +  # Gaussian fit to your budget
  0.08 * pref_score      +  # your personal taste history (from PostgreSQL click log)
  0.05 * time_boost      +  # time-of-day match (breakfast vs dinner)
  0.05 * dist_score      +  # GPS proximity (haversine)
  0.10 * mood_boost      +  # mood context (+25% bonus)
  0.05 * weather_boost   +  # weather context (+10% bonus)
  avoid_penalty             # recently eaten penalty (-30%)
).clip(0, 1)
```

Results are cached in a **3-layer stack**: Redis (30-min TTL) → PostgreSQL (persistent cache table) → ML recompute — fast responses without sacrificing freshness.

### RAG + LLM explainability layer

On top of the scoring engine, a semantic layer grounds and explains results:
- **ChromaDB** vector store with `multilingual-e5-large` embeddings (via `fastembed`), 33,707 restaurants indexed
- Hybrid retrieval: hard filters (city/budget) + soft cuisine boost + progressive relaxation
- LLM query understanding (`parse_query`) and grounded, hallucination-checked explanations (`explain_recommendations`) via Groq (Llama 20B/120B)
- Eval harness: ~94% avg field-level accuracy across a 22-query test set

### Conversational agent

A LangGraph `StateGraph` (router → parse → retrieve → retry-if-empty → explain → finalize, plus a click-intent branch) powers a stateful, multi-turn `/converse` endpoint, backed by Redis session storage (10-turn cap, 30-min TTL). Intent classification is deliberately lightweight rather than full agentic tool-calling, to keep latency low — documented in `PHASE3_SUMMARY_AND_INTERVIEW_PREP.md`.

---

## Features

### Core discovery
- Natural language search, including a full chat interface ("Ask GeoTaste") with follow-up support ("cheaper option?", "the first one, I loved it!")
- Mood-based recommendations (8 moods: celebrating, comfort, adventurous, etc.)
- Real-time weather context via OpenWeatherMap
- GPS proximity scoring with live location tracking
- Budget-aware Gaussian scoring
- Anti-repeat engine (avoids recently visited cuisines)
- Cuisine-level food images (prefetched from Unsplash, cached in Redis — zero added latency per request)

### Personalisation
- Taste profile built from click history — gets smarter the more you use it
- Cuisine Passport — 22 cuisine stamps tracking your food exploration, synced with the backend so progress survives logout
- Personal taste score (0–100 diversity index)

### Gamification
- XP system (restaurant tap = 10 XP, new cuisine = 25 XP, nearby visit = 50 XP)
- Level progression with XP bar
- 14 unlockable badges
- Daily streak tracking
- Weekly challenges with claimable XP rewards
- City leaderboard (live backend data, with a demo fallback when a city has too little activity)

### App
- Cross-platform: Android, iOS, Web (single Flutter codebase)
- **Light/dark theme toggle**, persisted across sessions
- JWT authentication
- Push notifications (meal-time reminders, streak alerts)
- Offline resilience — graceful Redis failover to PostgreSQL

---

## Architecture

```
┌─────────────────────────────────────────────────────┐
│                  Flutter App                         │
│  Provider state (PlacesProvider · GamificationProvider   │
│  · FavouritesProvider · ThemeProvider)                    │
│  GPS · Weather · Notifications · Chat UI · 6-tab nav      │
└──────────────────────┬──────────────────────────────┘
                       │ HTTP REST
┌──────────────────────▼──────────────────────────────┐
│              FastAPI Backend                         │
│  /recommend · /converse · /click · /leaderboard       │
│  /passport · /chat · /explain · /auth                 │
│  JWT auth · fuzzy city matching · CORS                │
└──────────┬──────────────────────┬───────────────────┘
           │                      │
┌──────────▼──────┐    ┌──────────▼──────────────────┐
│  Redis           │    │       PostgreSQL              │
│  Cache (L1) ·    │    │  users · places · clicks      │
│  chat sessions   │    │  cached_results (L2)          │
└─────────────────┘    └──────────────────────────────┘
                                  │
                       ┌──────────▼──────────────────┐
                       │       ML + RAG Engine         │
                       │  TF-IDF vectorizer (.pkl)     │
                       │  ChromaDB + fastembed         │
                       │  restaurants.parquet          │
                       │  7-signal score blend         │
                       └──────────┬──────────────────┘
                                  │
                       ┌──────────▼──────────────────┐
                       │   LangGraph Agent + Groq LLM  │
                       │   router/parse/retrieve/explain│
                       └─────────────────────────────┘
```

---

## Tech stack

| Layer | Technology |
|---|---|
| Frontend | Flutter (Dart), Provider, `geolocator`, `flutter_local_notifications` |
| Backend | Python FastAPI, SQLAlchemy ORM, Pydantic |
| Database | PostgreSQL (main), Redis (cache + chat sessions) |
| ML | TF-IDF vectorizer, cosine similarity, scikit-learn scaler |
| RAG / LLM | ChromaDB, fastembed (`multilingual-e5-large`), Groq (Llama), LangGraph |
| External APIs | OpenWeatherMap, Unsplash |
| Auth | JWT (access tokens, bcrypt hashing) |
| Storage | `.parquet` restaurant dataset, `.pkl` model artifacts |

---

## Project structure

```
geotaste-ai/
├── backend/
│   ├── main.py                   # FastAPI app, CORS, router registration
│   ├── config.py                 # Pydantic settings from .env
│   ├── database.py               # SQLAlchemy engine + session
│   ├── model_artifacts/
│   │   ├── restaurants.parquet
│   │   ├── tfidf_vectorizer.pkl
│   │   └── popularity_scaler.pkl
│   ├── models/                   # SQLAlchemy models (User, Place, UserClick, CachedResult)
│   ├── routes/                   # recommender, converse, auth, places
│   ├── schemas/                  # Pydantic request/response schemas
│   └── services/
│       ├── recommender.py        # ML scoring engine
│       ├── rag_engine.py         # ChromaDB hybrid retrieval
│       ├── llm_engine.py         # query parsing, grounded explanations
│       ├── chat_graph.py         # LangGraph StateGraph
│       ├── session_store.py      # Redis-backed conversation history
│       ├── image_service.py      # cuisine-level Unsplash image cache
│       └── cache.py              # 3-layer cache orchestration
│
└── frontend/ (lib/)
    ├── main.dart                 # MultiProvider + MaterialApp + MainShell
    ├── providers/                # PlacesProvider, GamificationProvider,
    │                             # FavouritesProvider, ThemeProvider
    ├── models/                   # PlaceModel, BadgeDefinition
    ├── screens/
    │   ├── home/                 # discover feed, passport, challenges, leaderboard
    │   ├── chat/                 # Ask GeoTaste conversational UI
    │   ├── gamification/         # progress/badges screen
    │   └── ...                   # splash, onboarding, auth, explore, profile
    ├── services/                 # ApiClient, LocationService, NotificationService,
    │                             # WeatherService
    ├── utils/
    │   └── app_theme.dart        # light + dark theme definitions ("Midnight Feast")
    └── widgets/                  # BadgeToast, StreakWidget, CityAutocomplete
```

---

## Getting started

### Prerequisites
- Python 3.10+
- Flutter 3.x
- PostgreSQL
- Redis (via WSL on Windows: `sudo service redis-server start`)

### Backend setup

```bash
cd backend
python -m venv .venv
.venv\Scripts\activate        # Windows
pip install -r requirements.txt

# copy and fill in your secrets
cp .env.example .env

# one-time: prefetch cuisine images into Redis
python rag/prefetch_cuisine_images.py

uvicorn main:app --reload
# API docs at http://localhost:8000/docs
```

### Frontend setup

```bash
cd frontend
flutter pub get

# for web
flutter run -d chrome

# for Android emulator (backend URL auto-switches to 10.0.2.2)
flutter run -d emulator
```

> Full restart (not hot reload) is required after pulling changes that add new model fields (e.g. `lat`/`lng`, `imageUrl` on `PlaceModel`).

### Environment variables

```dotenv
# .env.example
APP_NAME=GeoTaste AI
DEBUG=True
DATABASE_URL=postgresql://user:password@localhost:5432/geotaste
SECRET_KEY=your_secret_key_here
ALGORITHM=HS256
ACCESS_TOKEN_EXPIRE_MINUTES=60
REDIS_URL=redis://localhost:6379/0
OPENWEATHER_API_KEY=your_key_here
UNSPLASH_ACCESS_KEY=your_key_here
GROQ_API_KEY=your_key_here
```

---

## API reference

| Method | Endpoint | Description |
|---|---|---|
| `POST` | `/api/v1/recommend` | Get ML-scored restaurant recommendations |
| `POST` | `/api/v1/converse` | Stateful, multi-turn conversational search (LangGraph) |
| `POST` | `/api/v1/chat` | Single-turn RAG/LLM chat |
| `POST` | `/api/v1/explain` | Grounded explanation for a given recommendation |
| `POST` | `/api/v1/click` | Record user interaction (updates taste profile) |
| `POST` | `/api/v1/not-hungry` | Pause notifications for 60 minutes |
| `GET` | `/api/v1/cities` | List all available cities |
| `GET` | `/api/v1/cities/search?q=` | City autocomplete |
| `POST` | `/api/v1/auth/register` | Register new user |
| `POST` | `/api/v1/auth/login` | Login, returns JWT token |
| `GET` | `/api/v1/leaderboard` | City leaderboard by engagement |
| `GET` | `/api/v1/passport` | Server-side cuisine passport counts |
| `GET` | `/health` | Health check |

---

## Project status

- ✅ **Phase 1 — Core scoring engine**: 7-signal hybrid scorer, 3-layer cache, fuzzy city matching
- ✅ **Phase 2 — RAG + LLM**: ChromaDB hybrid retrieval, grounded explanations, ~94% eval accuracy
- ✅ **Phase 3 — Conversational agent**: LangGraph StateGraph, Redis session state, `/converse` endpoint, ChatScreen wired into the app
- ✅ Light/dark theme toggle across all screens
- 🔧 In progress: cuisine image pipeline verification (Redis cache population), final `add_coordinates.py` / `requirements.txt` diff review before push

### Known fixed issues (recent)
- Restaurant distance was always showing `0m` — backend wasn't including `lat`/`lng` in `/recommend` output; now included
- Leaderboard "This Week" tab rendered empty for cities with fewer than 3 active users — podium/list logic now handles partial data
- Chat recommendation cards and bot replies were unreadable in light mode — chat UI now uses fixed (always-dark) card colors independent of the app theme
- City search field ignored `Enter` when multiple city matches existed — now falls back to exact match or accepts typed input
- Cuisine filter chips included values (Momos, Chaat, Paneer) the backend didn't recognise, silently returning zero results — filter list now matches the backend's known cuisine set

---

## Roadmap

- Per-restaurant (not just per-cuisine) images
- Full agentic tool-calling for the conversational agent (currently lightweight intent classification, by design, for latency)
- Separate project: **ResearchCrew** — a CrewAI-based multi-agent research assistant (Planner/Search/Summarizer/Fact-Checker/Writer), Gemini + React/FastAPI, kept intentionally separate from GeoTaste's latency-conscious architecture