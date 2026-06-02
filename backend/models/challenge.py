# backend/models/challenge.py
# Records each challenge completion so XP is persisted and
# shows up on the leaderboard. One row per completion event
# (a user can complete the same challenge in different weeks).

from datetime import datetime
from sqlalchemy import Column, Integer, String, DateTime
from database import Base


class ChallengeCompletion(Base):
    __tablename__ = "challenge_completions"

    id           = Column(Integer, primary_key=True, index=True)
    username     = Column(String, index=True, nullable=False)
    challenge_id = Column(String, nullable=False)
    xp_reward    = Column(Integer, default=0, nullable=False)
    city         = Column(String, nullable=True)
    week_key     = Column(String, nullable=False)   # e.g. "2025-W22"
    completed_at = Column(DateTime, default=datetime.utcnow)

    def __repr__(self):
        return (
            f"<ChallengeCompletion {self.username}:"
            f"{self.challenge_id} week={self.week_key}>"
        )