# backend/config.py
from pydantic_settings import BaseSettings

class Settings(BaseSettings):
    APP_NAME:                    str   = "GeoTaste AI"
    DEBUG:                       bool  = False

    DATABASE_URL:                str
    SECRET_KEY:                  str   = "changeme"
    ALGORITHM:                   str   = "HS256"
    ACCESS_TOKEN_EXPIRE_MINUTES: int   = 60

    # FIX: REDIS_URL now explicitly declared so settings.REDIS_URL works
    REDIS_URL:                   str   = "redis://localhost:6379/0"

    class Config:
        env_file = ".env"

settings = Settings()