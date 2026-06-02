# backend/routes/auth.py
# Phase 4: register now saves city from UserCreate.
# /me endpoint returns city so Flutter can read it without hardcoding 'delhi'.

from fastapi import APIRouter, Depends, HTTPException
from fastapi.security import OAuth2PasswordRequestForm, HTTPBearer, HTTPAuthorizationCredentials
from sqlalchemy.orm import Session
from datetime import datetime, timedelta
from jose import JWTError, jwt
from passlib.context import CryptContext

from database import get_db
from models.user import User
from schemas.user import UserCreate, UserResponse, Token
from config import settings

router = APIRouter(prefix="/auth", tags=["Auth"])

pwd_context = CryptContext(schemes=["pbkdf2_sha256"], deprecated="auto")
auth_scheme = HTTPBearer()


# ── Utils ─────────────────────────────────────────────────────────────────────

def hash_password(password: str) -> str:
    return pwd_context.hash(password)


def verify_password(plain: str, hashed: str) -> bool:
    return pwd_context.verify(plain, hashed)


def create_access_token(data: dict, expires_delta: timedelta = None) -> str:
    to_encode = data.copy()
    expire    = datetime.utcnow() + (
        expires_delta or timedelta(minutes=settings.ACCESS_TOKEN_EXPIRE_MINUTES)
    )
    to_encode.update({"exp": expire})
    return jwt.encode(to_encode, settings.SECRET_KEY, algorithm=settings.ALGORITHM)


def decode_token(token: str):
    try:
        payload = jwt.decode(
            token, settings.SECRET_KEY, algorithms=[settings.ALGORITHM]
        )
        return payload.get("sub")
    except JWTError:
        return None


# ── Register ──────────────────────────────────────────────────────────────────

@router.post("/register", response_model=UserResponse, status_code=201)
def register(user_in: UserCreate, db: Session = Depends(get_db)):
    if db.query(User).filter(User.email == user_in.email).first():
        raise HTTPException(status_code=400, detail="Email already registered")

    if db.query(User).filter(User.username == user_in.username).first():
        raise HTTPException(status_code=400, detail="Username already taken")

    new_user = User(
        email=user_in.email,
        username=user_in.username,
        hashed_password=hash_password(user_in.password),
        city=user_in.city or "",      # ← Phase 4: persist city
        is_active=True,
    )
    db.add(new_user)
    db.commit()
    db.refresh(new_user)
    return new_user


# ── Login ─────────────────────────────────────────────────────────────────────
# OAuth2PasswordRequestForm sends application/x-www-form-urlencoded.
# Flutter sends the email value in the `username` field (OAuth2 spec naming).
# We query by email on the backend.

@router.post("/login", response_model=Token)
def login(
    db:        Session = Depends(get_db),
    form_data: OAuth2PasswordRequestForm = Depends(),
):
    user = db.query(User).filter(User.email == form_data.username).first()
    if not user or not verify_password(form_data.password, user.hashed_password):
        raise HTTPException(status_code=401, detail="Invalid email or password")

    access_token = create_access_token(data={"sub": str(user.id)})
    return {"access_token": access_token, "token_type": "bearer"}


# ── Dependency: get current user from Bearer token ────────────────────────────

def get_current_user(
    credentials: HTTPAuthorizationCredentials = Depends(auth_scheme),
    db:          Session = Depends(get_db),
) -> User:
    subject = decode_token(credentials.credentials)
    if not subject:
        raise HTTPException(status_code=401, detail="Invalid or expired token")

    user = db.query(User).filter(User.id == int(subject)).first()
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    return user


# ── /me — returns full user profile including city ────────────────────────────

@router.get("/me", response_model=UserResponse)
def get_me(current_user: User = Depends(get_current_user)):
    # Phase 4: city is now part of UserResponse so Flutter reads it here
    return current_user


# ── PATCH /me/city — update city after login ──────────────────────────────────

@router.patch("/me/city")
def update_city(
    payload:      dict,
    current_user: User    = Depends(get_current_user),
    db:           Session = Depends(get_db),
):
    """
    Flutter can call this when the user changes city from the home screen
    so the server-side profile stays in sync.
    Body: {"city": "bhopal"}
    """
    city = payload.get("city", "").strip().lower()
    if city:
        current_user.city = city
        db.commit()
    return {"status": "updated", "city": current_user.city}