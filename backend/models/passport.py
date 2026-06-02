# backend/models/passport.py
# Stores per-user cuisine tap counts so they persist across sessions
# and feed the leaderboard XP calculation.
# One row per (username, cuisine) pair — upserted on every sync.

from datetime import datetime
from sqlalchemy import Column, Integer, String, DateTime
from database import Base


class PassportEntry(Base):
    __tablename__ = "passport_entries"

    id         = Column(Integer, primary_key=True, index=True)
    username   = Column(String, index=True, nullable=False)
    cuisine    = Column(String, nullable=False)
    tap_count  = Column(Integer, default=1, nullable=False)
    city       = Column(String, nullable=True)
    updated_at = Column(DateTime, default=datetime.utcnow,
                        onupdate=datetime.utcnow)

    def __repr__(self):
        return f"<PassportEntry {self.username}:{self.cuisine}={self.tap_count}>"