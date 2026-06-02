# 🍽️ GeoTaste AI

> **Discover food you'll actually love** — a smart restaurant discovery app powered by a multi-signal ML recommendation engine that learns your taste, reads your mood, and checks the weather before suggesting where to eat.

![Flutter](https://img.shields.io/badge/Flutter-02569B?style=flat&logo=flutter&logoColor=white)
![FastAPI](https://img.shields.io/badge/FastAPI-005571?style=flat&logo=fastapi)
![Python](https://img.shields.io/badge/Python-3776AB?style=flat&logo=python&logoColor=white)
![PostgreSQL](https://img.shields.io/badge/PostgreSQL-316192?style=flat&logo=postgresql&logoColor=white)
![Redis](https://img.shields.io/badge/Redis-DD0031?style=flat&logo=redis&logoColor=white)

---

## What is GeoTaste?

GeoTaste is a **cross-platform food discovery app** (not delivery) that recommends restaurants based on who you are, not just where you are. Instead of showing the same top-rated places everyone else sees, it combines 7 real-time signals to surface restaurants that match *you* in this moment.

**Built with:** Flutter (Android + iOS + Web) · Python FastAPI · PostgreSQL · Redis · TF-IDF + cosine similarity ML

---

## How the recommendation engine works

The core of GeoTaste is a scoring pipeline that blends 7 weighted signals for every restaurant candidate:

```python
final_score = (
  0.25 * sim_score       +  # TF-IDF query match (what you searched)
  0.18 * rating_score    +  # normalised restaurant rating
  0.12 * popularity_norm +  # popularity signal
  0.12 * budget_score    +  # Gaussian fit to your budget
  0.08 * pref_score      +  # your personal taste history
  0.05 * time_boost      +  # time-of-day match (breakfast vs dinner)
  0.05 * dist_score      +  # GPS proximity
  0.10 * mood_boost      +  # mood context (+25% bonus)
  0.05 * weather_boost   +  # weather context (+10% bonus)
  avoid_penalty             # recently eaten penalty (-30%)
).clip(0, 1)
```

Results are cached in a **3-layer stack**: Redis (30-min TTL) → PostgreSQL (persistent cache table) → ML recompute. This means fast responses without sacrificing freshness.

---

## Features

### Core discovery
- Natural language search ("biryani near me under ₹300")
- Mood-based recommendations (8 moods: celebrating, comfort, adventurous, etc.)
- Real-time weather context via OpenWeatherMap
- GPS proximity scoring with live location tracking
- Budget-aware Gaussian scoring
- Anti-repeat engine (avoids recently visited cuisines)

### Personalisation
- Taste profile built from click history — gets smarter the more you use it
- Cuisine Passport — 22 cuisine stamps tracking your food exploration
- Personal taste score (0–100 diversity index)

### Gamification
- XP system (restaurant tap = 10 XP, new cuisine = 25 XP, nearby visit = 50 XP)
- Level progression with XP bar
- 14 unlockable badges
- Daily streak tracking
- City leaderboard

### App
- Cross-platform: Android, iOS, Web (single Flutter codebase)
- JWT authentication
- Push notifications (meal-time reminders, streak alerts)
- Offline resilience — graceful Redis failover to PostgreSQL

---

## Architecture

```
┌─────────────────────────────────────────────────────┐
│                  Flutter App                         │
│  Provider state (PlacesProvider · GamificationProvider · FavouritesProvider)  │
│  GPS · Weather · Notifications · 6-tab navigation   │
└──────────────────────┬──────────────────────────────┘
                       │ HTTP REST
┌──────────────────────▼──────────────────────────────┐
│              FastAPI Backend                         │
│  /recommend · /click · /leaderboard · /auth          │
│  JWT auth · fuzzy city matching · CORS               │
└──────────┬──────────────────────┬───────────────────┘
           │                      │
┌──────────▼──────┐    ┌──────────▼──────────────────┐
│  Redis Cache    │    │       PostgreSQL              │
│  30-min TTL     │    │  users · places · clicks      │
│  Layer 1        │    │  cached_results  (Layer 2)    │
└─────────────────┘    └──────────────────────────────┘
                                  │
                       ┌──────────▼──────────────────┐
                       │       ML Engine              │
                       │  TF-IDF vectorizer (.pkl)    │
                       │  restaurants.parquet         │
                       │  7-signal score blend        │
                       └─────────────────────────────┘
```

---

## Tech stack

| Layer | Technology |
|---|---|
| Frontend | Flutter (Dart), Provider, `geolocator`, `flutter_local_notifications` |
| Backend | Python FastAPI, SQLAlchemy ORM, Pydantic |
| Database | PostgreSQL (main), Redis (cache layer) |
| ML | TF-IDF vectorizer, cosine similarity, scikit-learn scaler |
| External APIs | OpenWeatherMap |
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
│   ├── routes/                   # recommender, auth, places
│   ├── schemas/                  # Pydantic request/response schemas
│   └── services/
│       ├── recommender.py        # ML scoring engine
│       └── cache.py              # 3-layer cache orchestration
│
└── frontend/ (lib/)
    ├── main.dart                 # MultiProvider + MaterialApp + MainShell
    ├── providers/                # PlacesProvider, GamificationProvider, FavouritesProvider
    ├── models/                   # PlaceModel, BadgeDefinition
    ├── screens/                  # splash, onboarding, auth, home, explore, progress, profile
    ├── services/                 # ApiClient, LocationService, NotificationService, WeatherService
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

# run migrations and start
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
```

---

## API reference

| Method | Endpoint | Description |
|---|---|---|
| `POST` | `/api/v1/recommend` | Get ML-scored restaurant recommendations |
| `POST` | `/api/v1/click` | Record user interaction (updates taste profile) |
| `POST` | `/api/v1/not-hungry` | Pause notifications for 60 minutes |
| `GET` | `/api/v1/cities` | List all available cities |
| `GET` | `/api/v1/cities/search?q=` | City autocomplete |
| `POST` | `/api/v1/auth/register` | Register new user |
| `POST` | `/api/v1/auth/login` | Login, returns JWT token |
| `GET` | `/api/v1/leaderboard` | City leaderboard by engagement |
| `GET` | `/health` | Health check |

---

## Roadmap

- [ ] Docker Compose setup for one-command local start
- [ ] Challenge completion backend persistence
- [ ] Passport sync across devices (currently local)
- [ ] Collaborative filtering to replace/augment TF-IDF
- [ ] Model evaluation dashboard (precision@k, coverage)
- [ ] Production deployment (Railway / Render)

---