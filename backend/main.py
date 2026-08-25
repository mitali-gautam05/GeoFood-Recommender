# backend/main.py
# Phase 3: social router uncommented, new models imported.

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from database import Base, engine

from models import user, place
from models.user_click    import UserClick
from models.cached_result import CachedResult
from models.passport      import PassportEntry        
from models.challenge     import ChallengeCompletion 

from routes.recommender import router as recommender_router
from routes.auth        import router as auth_router
from routes.places      import router as places_router
from routes.social      import router as social_router  
from routes.chat import router as chat_router
from routes.converse import router as converse_router


app = FastAPI(
    title="GeoTaste-AI",
    description="Intelligent food recommendation API",
    version="1.0.0",
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=False,
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.on_event("startup")
def startup():
    # Creates passport_entries and challenge_completions tables if not present
    Base.metadata.create_all(bind=engine)


app.include_router(auth_router,        prefix="/api/v1")
app.include_router(places_router,      prefix="/api/v1")
app.include_router(recommender_router, prefix="/api/v1", tags=["Recommender"])
app.include_router(social_router,      prefix="/api/v1")  # ← Phase 3
app.include_router(chat_router, prefix="/api/v1", tags=["Chat"])
app.include_router(converse_router, prefix="/api/v1", tags=["Converse"])


@app.get("/health")
def health():
    return {"status": "ok"}


@app.get("/")
def root():
    return {
        "message": "GeoTaste-AI backend is running",
        "docs":    "/docs",
        "health":  "/health",
    }