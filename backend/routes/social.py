# backend/routes/social.py
# Phase 3 — three endpoints:
#   POST /passport/sync      — upsert cuisine counts from Flutter
#   GET  /passport           — read server-side counts for a user
#   GET  /leaderboard        — city weekly leaderboard from user_clicks + challenges
#   POST /challenge/complete — record a challenge completion + XP

from datetime import datetime, timedelta
from typing import Optional

from fastapi import APIRouter, Depends, Query
from sqlalchemy import func
from sqlalchemy.orm import Session

from database import get_db
from models.user_click import UserClick
from models.passport   import PassportEntry
from models.challenge  import ChallengeCompletion
from schemas.social import (
    PassportSyncRequest,  PassportSyncResponse,
    PassportGetResponse,
    LeaderboardResponse,  LeaderboardEntry,
    ChallengeCompleteRequest, ChallengeCompleteResponse,
)

router = APIRouter(tags=["Social"])


# ── Helpers ───────────────────────────────────────────────────────────────────

def _week_key(dt: datetime = None) -> str:
    """ISO week key, e.g. '2025-W22'"""
    d = dt or datetime.utcnow()
    return f"{d.year}-W{d.isocalendar()[1]:02d}"


def _week_start(dt: datetime = None) -> str:
    """Monday of the current ISO week as 'YYYY-MM-DD'"""
    d = (dt or datetime.utcnow()).date()
    monday = d - timedelta(days=d.weekday())
    return monday.isoformat()


def _xp_from_clicks(click_count: int) -> int:
    """10 XP per click — mirrors Flutter XpAction.restaurantTap"""
    return click_count * 10


def _badge_count_for_user(username: str, db: Session) -> int:
    """Count distinct completed challenges as a badge proxy."""
    return (
        db.query(func.count(ChallengeCompletion.id))
        .filter(ChallengeCompletion.username == username)
        .scalar()
        or 0
    )


# ── POST /passport/sync ───────────────────────────────────────────────────────

@router.post("/passport/sync", response_model=PassportSyncResponse)
def sync_passport(req: PassportSyncRequest, db: Session = Depends(get_db)):
    """
    Flutter sends its local cuisineClickMap on every tap.
    We upsert each cuisine row (take the MAX of local vs server so
    neither side ever loses data).
    """
    merged: dict[str, int] = {}

    for cuisine, local_count in req.cuisine_counts.items():
        key = cuisine.strip().lower()
        row = (
            db.query(PassportEntry)
            .filter(
                PassportEntry.username == req.username,
                PassportEntry.cuisine  == key,
            )
            .first()
        )
        if row:
            # Take the higher of the two counts
            row.tap_count  = max(row.tap_count, local_count)
            row.updated_at = datetime.utcnow()
            if req.city:
                row.city = req.city
        else:
            row = PassportEntry(
                username  = req.username,
                cuisine   = key,
                tap_count = local_count,
                city      = req.city or "",
            )
            db.add(row)
        merged[key] = row.tap_count

    db.commit()
    return PassportSyncResponse(
        status="synced", username=req.username, merged=merged
    )


# ── GET /passport ─────────────────────────────────────────────────────────────

@router.get("/passport", response_model=PassportGetResponse)
def get_passport(
    username: str = Query(..., min_length=1),
    db: Session = Depends(get_db),
):
    rows = (
        db.query(PassportEntry)
        .filter(PassportEntry.username == username)
        .all()
    )
    counts = {row.cuisine: row.tap_count for row in rows}
    return PassportGetResponse(username=username, cuisine_counts=counts)


# ── GET /leaderboard ──────────────────────────────────────────────────────────

@router.get("/leaderboard", response_model=LeaderboardResponse)
def get_leaderboard(
    city:     str = Query(..., min_length=1),
    username: Optional[str] = Query(None),
    db: Session = Depends(get_db),
):
    """
    Weekly leaderboard for a city.
    XP = (clicks this week × 10) + (challenge XP this week).
    All-time XP = (total clicks × 10) + (all challenge XP).
    """
    week_start_dt = datetime.utcnow() - timedelta(
        days=datetime.utcnow().weekday()
    )
    week_start_dt = week_start_dt.replace(
        hour=0, minute=0, second=0, microsecond=0
    )
    wk = _week_key()

    # ── Weekly click XP per user for this city ─────────────────────────────
    weekly_clicks = (
        db.query(
            UserClick.username,
            func.count(UserClick.id).label("click_count"),
        )
        .filter(
            func.lower(UserClick.city) == city.lower(),
            UserClick.clicked_at >= week_start_dt,
        )
        .group_by(UserClick.username)
        .all()
    )

    # ── Weekly challenge XP per user for this city ─────────────────────────
    weekly_challenge_xp = (
        db.query(
            ChallengeCompletion.username,
            func.sum(ChallengeCompletion.xp_reward).label("challenge_xp"),
        )
        .filter(
            func.lower(ChallengeCompletion.city) == city.lower(),
            ChallengeCompletion.week_key == wk,
        )
        .group_by(ChallengeCompletion.username)
        .all()
    )

    # ── All-time click XP per user for this city ───────────────────────────
    all_clicks = (
        db.query(
            UserClick.username,
            func.count(UserClick.id).label("click_count"),
        )
        .filter(func.lower(UserClick.city) == city.lower())
        .group_by(UserClick.username)
        .all()
    )

    # ── All-time challenge XP per user ─────────────────────────────────────
    all_challenge_xp = (
        db.query(
            ChallengeCompletion.username,
            func.sum(ChallengeCompletion.xp_reward).label("challenge_xp"),
        )
        .filter(func.lower(ChallengeCompletion.city) == city.lower())
        .group_by(ChallengeCompletion.username)
        .all()
    )

    # ── Merge into per-user dict ───────────────────────────────────────────
    users: dict[str, dict] = {}

    for row in weekly_clicks:
        u = users.setdefault(row.username, {
            "weekly_xp": 0, "total_xp": 0, "badge_count": 0
        })
        u["weekly_xp"] += _xp_from_clicks(row.click_count)

    for row in weekly_challenge_xp:
        u = users.setdefault(row.username, {
            "weekly_xp": 0, "total_xp": 0, "badge_count": 0
        })
        u["weekly_xp"] += int(row.challenge_xp or 0)

    for row in all_clicks:
        u = users.setdefault(row.username, {
            "weekly_xp": 0, "total_xp": 0, "badge_count": 0
        })
        u["total_xp"] += _xp_from_clicks(row.click_count)

    for row in all_challenge_xp:
        u = users.setdefault(row.username, {
            "weekly_xp": 0, "total_xp": 0, "badge_count": 0
        })
        u["total_xp"] += int(row.challenge_xp or 0)

    if not users:
        return LeaderboardResponse(
            status="empty", city=city,
            week_start=_week_start(), entries=[],
        )

    # ── Badge counts ───────────────────────────────────────────────────────
    for uname in users:
        users[uname]["badge_count"] = _badge_count_for_user(uname, db)

    # ── Sort by weekly XP descending ───────────────────────────────────────
    sorted_users = sorted(
        users.items(), key=lambda x: x[1]["weekly_xp"], reverse=True
    )

    entries = [
        LeaderboardEntry(
            rank=i + 1,
            username=uname,
            weekly_xp=data["weekly_xp"],
            total_xp=data["total_xp"],
            city=city,
            badge_count=data["badge_count"],
        )
        for i, (uname, data) in enumerate(sorted_users[:20])
    ]

    # ── Find requesting user's entry ───────────────────────────────────────
    my_entry = None
    if username:
        for entry in entries:
            if entry.username == username:
                my_entry = entry
                break
        # If user not in top 20 — compute their rank separately
        if my_entry is None and username in users:
            my_rank = (
                sum(1 for u in users.values()
                    if u["weekly_xp"] > users[username]["weekly_xp"])
                + 1
            )
            my_entry = LeaderboardEntry(
                rank=my_rank,
                username=username,
                weekly_xp=users[username]["weekly_xp"],
                total_xp=users[username]["total_xp"],
                city=city,
                badge_count=users[username]["badge_count"],
            )

    return LeaderboardResponse(
        status="ok",
        city=city,
        week_start=_week_start(),
        entries=entries,
        my_entry=my_entry,
    )


# ── POST /challenge/complete ──────────────────────────────────────────────────

@router.post("/challenge/complete", response_model=ChallengeCompleteResponse)
def complete_challenge(
    req: ChallengeCompleteRequest,
    db: Session = Depends(get_db),
):
    """
    Records a challenge completion. Idempotent — if the user already
    completed this challenge in the same week, returns 'already_completed'
    without double-awarding XP.
    """
    wk = _week_key()

    existing = (
        db.query(ChallengeCompletion)
        .filter(
            ChallengeCompletion.username     == req.username,
            ChallengeCompletion.challenge_id == req.challenge_id,
            ChallengeCompletion.week_key     == wk,
        )
        .first()
    )

    if existing:
        return ChallengeCompleteResponse(
            status="already_completed",
            username=req.username,
            challenge_id=req.challenge_id,
            xp_reward=0,
            week_key=wk,
        )

    db.add(ChallengeCompletion(
        username=req.username,
        challenge_id=req.challenge_id,
        xp_reward=req.xp_reward,
        city=req.city or "",
        week_key=wk,
    ))
    db.commit()

    return ChallengeCompleteResponse(
        status="recorded",
        username=req.username,
        challenge_id=req.challenge_id,
        xp_reward=req.xp_reward,
        week_key=wk,
    )