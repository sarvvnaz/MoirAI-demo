from __future__ import annotations
from fastapi import APIRouter, Depends, HTTPException, status
from fastapi.security import OAuth2PasswordRequestForm
from sqlalchemy.orm import Session
from app.schemas import UserCreate
from app.database.db_setup import get_db
from app.database import models
from app.services.security import (
    hash_password,
    verify_password,
    create_access_token,
    get_current_user,
)


router = APIRouter(prefix="/auth", tags=["Auth"])

# ─────────────────────────────
# SIGNUP
# ─────────────────────────────


@router.post("/signup", status_code=status.HTTP_201_CREATED)
def signup(user: UserCreate, db: Session = Depends(get_db)):
    existing_user = db.query(models.User).filter(models.User.username == user.username).first()
    if existing_user:
        raise HTTPException(status_code=400, detail="Username already registered")

    db_user = models.User(
        username=user.username,
        password_hash=hash_password(user.password),
        full_name_fa=user.full_name_fa,
        english_goal=user.english_goal,
    )
    db.add(db_user)
    db.commit()
    db.refresh(db_user)

    return {"message": "User created successfully", "user_id": db_user.id}


# ─────────────────────────────
# LOGIN
# ─────────────────────────────
@router.post("/login")
def login(form_data: OAuth2PasswordRequestForm = Depends(), db: Session = Depends(get_db)):
    user = db.query(models.User).filter(models.User.username == form_data.username).first()
    if not user or not verify_password(form_data.password, user.password_hash):

        raise HTTPException(status_code=401, detail="Invalid username or password")

    access_token = create_access_token({"sub": user.username})
    return {
        "access_token": access_token,
        "token_type": "bearer",
        "user": {
            "id": user.id,
            "username": user.username,
            "full_name_fa": user.full_name_fa,
            "english_goal": user.english_goal
        }
    }


# ─────────────────────────────
# CURRENT USER
# ─────────────────────────────
@router.get("/me")
def get_me(current_user: models.User = Depends(get_current_user)):
    """
    Return the currently authenticated user.
    """
    return {
        "id": current_user.id,
        "username": current_user.username,
        "full_name_fa": current_user.full_name_fa,
        "english_goal": current_user.english_goal,
        "created_at": current_user.created_at,
    }
