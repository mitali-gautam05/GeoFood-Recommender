# backend/schemas/user.py
# Phase 4: city field added to UserCreate and UserResponse.
# Optional in UserCreate so existing clients that don't send city still work.

from pydantic import BaseModel, EmailStr, Field
from typing import Optional
from datetime import datetime


class UserCreate(BaseModel):
    email:    EmailStr
    username: str           = Field(min_length=3, max_length=50)
    password: str           = Field(min_length=6)
    city:     Optional[str] = ""     # ← Phase 4: optional, defaults to ""


class UserLogin(BaseModel):
    email:    EmailStr
    password: str


class Token(BaseModel):
    access_token: str
    token_type:   str


class UserResponse(BaseModel):
    id:         int
    email:      EmailStr
    username:   str
    is_active:  bool
    city:       Optional[str] = ""   # ← Phase 4
    created_at: Optional[datetime] = None

    class Config:
        from_attributes = True