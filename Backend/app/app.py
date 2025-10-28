from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from app.database.db_setup import Base, engine
from app.database import models
from app.routers import auth, eft, nudges, events
from app.routers import events

# Ensure tables exist in dev
Base.metadata.create_all(bind=engine)

app = FastAPI(title="NeuroNudge Research Backend")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # relax for dev; tighten in prod
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(auth.router)    # /auth
app.include_router(eft.router)     # /eft
app.include_router(nudges.router)  # /nudges
app.include_router(events.router)  # /events

@app.get("/")
def root():
    return {"message": "Backend running ✅"}
