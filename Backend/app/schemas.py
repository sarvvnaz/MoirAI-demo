# app/schemas.py
from pydantic import BaseModel, EmailStr, field_validator
from typing import Optional


class UserCreate(BaseModel):
    email: EmailStr
    full_name_fa: str

    @field_validator("email")
    @classmethod
    def normalize_email(cls, v: EmailStr) -> str:
        return v.strip().lower()


class UserLogin(BaseModel):
    email: EmailStr

    @field_validator("email")
    @classmethod
    def normalize_email(cls, v: EmailStr) -> str:
        return v.strip().lower()

class UserResponse(BaseModel):
    id: int                
    email: EmailStr
    full_name_fa: str
    created_at: Optional[str] = None   

    class Config:
        orm_mode = True