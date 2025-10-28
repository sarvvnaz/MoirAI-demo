from __future__ import annotations
import os
from pathlib import Path
from dotenv import load_dotenv
from datetime import timedelta

# ─────────────────────────────
# ENVIRONMENT SETUP
# ─────────────────────────────

# Locate the Backend folder (parent of /app)
BASE_DIR = Path(__file__).resolve().parent
ENV_PATH = BASE_DIR / ".env"
DB_PATH = BASE_DIR / "database" / "app.db"
DATABASE_URL = f"sqlite:///{DB_PATH}"

ENV_PATH = BASE_DIR / ".env"

# Load environment variables from .env in /Backend
load_dotenv(ENV_PATH)

# ─────────────────────────────
# CORE SETTINGS
# ─────────────────────────────

# Database URL (SQLite by default)
DATABASE_URL = os.getenv("DATABASE_URL", "sqlite:///./app/database/app.db")

# OpenAI API key
OPENAI_API_KEY = os.getenv("OPENAI_API_KEY")

# JWT / Auth settings
SECRET_KEY = os.getenv("SECRET_KEY", "supersecretkey")
JWT_ALGORITHM = os.getenv("JWT_ALGORITHM", "HS256")

# Expiry (in minutes)

ACCESS_TOKEN_EXPIRE_MINUTES = int(os.getenv("ACCESS_TOKEN_EXPIRE_MINUTES", 120))
ACCESS_TOKEN_EXPIRE_DELTA = timedelta(minutes=ACCESS_TOKEN_EXPIRE_MINUTES)

# ─────────────────────────────
# OTHER OPTIONAL SETTINGS
# ─────────────────────────────

APP_NAME = os.getenv("APP_NAME", "NeuroNudge Research Backend")
DEBUG_MODE = os.getenv("DEBUG_MODE", "True").lower() == "true"
