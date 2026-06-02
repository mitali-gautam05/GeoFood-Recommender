# backend/schemas/social.py
# Pydantic request/response schemas for routes/social.py

from pydantic import BaseModel
from typing import Dict, List, Optional


# ── Passport sync ──────────────────────────────────────────────────────────────

class PassportSyncRequest(BaseModel):
    username:       str
    cuisine_counts: Dict[str, int]   # {"biryani": 3, "chinese": 1, ...}
    city:           Optional[str] = ""


class PassportSyncResponse(BaseModel):
    status:   str                    # "synced"
    username: str
    merged:   Dict[str, int]         # server-side merged counts


class PassportGetResponse(BaseModel):
    username:       str
    cuisine_counts: Dict[str, int]


# ── Leaderboard ────────────────────────────────────────────────────────────────

class LeaderboardEntry(BaseModel):
    rank:        int
    username:    str
    weekly_xp:   int
    total_xp:    int
    city:        str
    badge_count: int


class LeaderboardResponse(BaseModel):
    status:     str                       # "ok" | "empty"
    city:       str
    week_start: str                       # ISO date string "2025-05-26"
    entries:    List[LeaderboardEntry]
    my_entry:   Optional[LeaderboardEntry] = None


# ── Challenge complete ─────────────────────────────────────────────────────────

class ChallengeCompleteRequest(BaseModel):
    username:     str
    challenge_id: str
    xp_reward:    int
    city:         Optional[str] = ""


class ChallengeCompleteResponse(BaseModel):
    status:       str    # "recorded" | "already_completed"
    username:     str
    challenge_id: str
    xp_reward:    int
    week_key:     str