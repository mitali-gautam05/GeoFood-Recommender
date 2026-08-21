# backend/config.py
from pathlib import Path
from pydantic_settings import BaseSettings

class Settings(BaseSettings):
    APP_NAME:                    str   = "GeoTaste AI"
    DEBUG:                       bool  = False
    DATABASE_URL:                str
    SECRET_KEY:                  str   = "changeme"
    ALGORITHM:                   str   = "HS256"
    ACCESS_TOKEN_EXPIRE_MINUTES: int   = 60
    REDIS_URL:                   str   = "redis://localhost:6379/0"
    GROQ_API_KEY :               str
    class Config:
        env_file = Path(__file__).resolve().parent / ".env"

settings = Settings()