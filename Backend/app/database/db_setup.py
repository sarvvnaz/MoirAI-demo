from __future__ import annotations

from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker, declarative_base
from sqlalchemy.engine import Engine
from sqlalchemy.pool import StaticPool

from app.config import DATABASE_URL

# SQLite needs special args for multithreaded FastAPI usage.
if DATABASE_URL.startswith("sqlite"):
    engine: Engine = create_engine(
        DATABASE_URL,
        connect_args={"check_same_thread": False},
        poolclass=StaticPool if DATABASE_URL.endswith(":memory:") else None,
    )
else:
    engine: Engine = create_engine(DATABASE_URL)

SessionLocal = sessionmaker(bind=engine, autoflush=False, autocommit=False, future=True)
Base = declarative_base()

def get_db():
    """
    FastAPI dependency: yields a SQLAlchemy session and guarantees close().
    """
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()
if __name__ == "__main__":
    from app.database import models
    print("Creating database tables...")
    Base.metadata.create_all(bind=engine)
    print("✅ All tables created successfully!")
