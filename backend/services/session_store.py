"""
services/session_store.py

Phase 3: conversation session state, stored in Redis -- reuses the same
connection as services/cache.py (get_redis()), no new connection pool.
Each session is a short list of recent turns, keyed by username, with a
TTL so idle conversations expire on their own instead of growing forever.

Fails soft throughout, same pattern as cache.py: if Redis is
unavailable, every function degrades to acting like a fresh session
(empty history) rather than raising -- a broken session store should
never crash a chat request. Worst case, the agent just treats every
turn as a new conversation instead of a follow-up.
"""

import json
import logging
from datetime import datetime

from services.cache import get_redis

logger = logging.getLogger(__name__)

SESSION_TTL_SECONDS = 1800   # 30 min idle -> conversation resets, matches cache.py's TTL
MAX_TURNS = 10                # caps history length so it never grows unbounded


def _session_key(username: str) -> str:
    return f"session:{username}"


def get_session_history(username: str) -> list:
    """
    Returns the list of recent turns for this user, oldest first. Each
    turn is a dict, e.g. {"query": ..., "city": ..., "parsed_filters":
    ..., "timestamp": ...}.

    Returns [] if Redis is unavailable or no session exists yet -- the
    Router node should treat that as "no prior context, this is a new
    conversation."
    """
    r = get_redis()
    if r is None:
        return []
    try:
        raw = r.get(_session_key(username))
        return json.loads(raw) if raw else []
    except Exception as e:
        logger.warning(f"Session history GET error for {username}: {e}")
        return []


def append_turn(username: str, turn: dict) -> None:
    """
    Appends one turn to the user's session history, trims to the last
    MAX_TURNS, and refreshes the TTL -- an active back-and-forth
    conversation doesn't expire mid-chat, only after real idle time.

    No-ops silently if Redis is unavailable: the current request still
    completes normally, it just won't have follow-up context available
    on the next turn.
    """
    r = get_redis()
    if r is None:
        return
    try:
        turn = {**turn, "timestamp": datetime.utcnow().isoformat()}
        history = get_session_history(username)
        history.append(turn)
        history = history[-MAX_TURNS:]
        r.setex(_session_key(username), SESSION_TTL_SECONDS, json.dumps(history))
    except Exception as e:
        logger.warning(f"Session history SET error for {username}: {e}")


def clear_session(username: str) -> None:
    """Explicitly ends a conversation, e.g. if the Router detects the
    user has genuinely switched topics rather than following up."""
    r = get_redis()
    if r is None:
        return
    try:
        r.delete(_session_key(username))
    except Exception as e:
        logger.warning(f"Session clear error for {username}: {e}")