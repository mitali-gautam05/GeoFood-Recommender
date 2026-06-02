"""
Run from backend directory:
  .venv\Scripts\python add_city_column.py
"""
from sqlalchemy import text
from database import engine

with engine.connect() as conn:
    conn.execute(text("ALTER TABLE users ADD COLUMN IF NOT EXISTS city VARCHAR DEFAULT ''"))
    conn.commit()

print("Done — city column added (or already existed).")