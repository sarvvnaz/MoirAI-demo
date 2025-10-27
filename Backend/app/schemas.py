# app/schemas.py
from pydantic import BaseModel
from typing import Optional


class UserCreate(BaseModel):
    username: str
    password: str
    full_name_fa: str | None = None
    english_goal: str | None = None


class UserLogin(BaseModel):
    username: str
    password: str


class UserResponse(BaseModel):
    id: int
    username: str
    full_name_fa: Optional[str]
    english_goal: Optional[str]

    class Config:
        orm_mode = True
