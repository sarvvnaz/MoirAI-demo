from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from app.database.db_setup import Base, engine
from app.database import models
from app.routers import auth, eft, nudges, events
from app.routers import events
import app.routers.sessions as sessions
from fastapi.staticfiles import StaticFiles
from app.routers.auth import router as auth_router
# Ensure tables exist in dev
Base.metadata.create_all(bind=engine)

app = FastAPI(title="NeuroNudge Research Backend")
# 🔹 CORS setup for frontend access
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

# 🔹 APIs live under /api/...
app.include_router(auth.router)
app.include_router(eft.router)
app.include_router(nudges.router)
app.include_router(events.router)
print(app.routes)

# 🔹 Serve Flutter build at ROOT
app.mount("/", StaticFiles(directory="web", html=True), name="web")

