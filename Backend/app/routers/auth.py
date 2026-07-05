from __future__ import annotations
from fastapi import APIRouter, Depends, HTTPException, status
from fastapi.security import OAuth2PasswordRequestForm
from sqlalchemy.orm import Session
from app.schemas import UserCreate, UserLogin
from app.database.db_setup import get_db
from app.database import models
from app.services.security import (
    create_access_token,
    get_current_user,
)


router = APIRouter(prefix="/api/auth", tags=["Auth"])

# ─────────────────────────────
# SIGNUP
# ─────────────────────────────


@router.post("/signup", status_code=status.HTTP_201_CREATED)
def signup(user: UserCreate, db: Session = Depends(get_db)):
    if db.query(models.User).filter(models.User.email == user.email).first():
        raise HTTPException(status_code=409, detail="Email already registered")

    user = models.User(email=user.email, full_name_fa=user.full_name_fa)
    db.add(user)
    db.commit()
    db.refresh(user)
    return {"signup_ok": True, "user_id": user.id}


# ─────────────────────────────
# LOGIN
# ─────────────────────────────
@router.post("/login")
def login(body: UserLogin, db: Session = Depends(get_db)):
    user = db.query(models.User).filter(models.User.email == body.email).first()
    if not user :
        raise HTTPException(status_code=401, detail="Invalid credentials")

    access_token = create_access_token({"sub": user.email})
    return {
        "access_token": access_token,
        "token_type": "bearer",
        "user": {
            "id": user.id,
            "email": user.email,
            "full_name_fa": user.full_name_fa,
        }
    }

# ─────────────────────────────
# CURRENT USER
# ─────────────────────────────
@router.get("/me")
def me(current_user: models.User = Depends(get_current_user)):
    return {
        "id": current_user.id,
        "email": current_user.email,
        "full_name_fa": current_user.full_name_fa,
        "created_at": current_user.created_at,
        "age": current_user.age,
        "gender": current_user.gender,
        "degree": current_user.degree,
        "examGoal": current_user.examGoal,
        "studyHoursPerWeek": current_user.studyHoursPerWeek,
    }