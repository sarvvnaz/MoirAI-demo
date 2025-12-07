# security.py
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from fastapi import HTTPException, status, Depends
from jose import jwt, JWTError
from datetime import datetime, timedelta
from typing import Optional
from app.database.db_setup import SessionLocal
from app.database.models import User
from app.config import SECRET_KEY, JWT_ALGORITHM, ACCESS_TOKEN_EXPIRE_DELTA  # your constants

bearer_scheme = HTTPBearer(auto_error=True)

def create_access_token(data: dict, expires_delta: Optional[timedelta] = None) -> str:
    to_encode = data.copy()
    expire = datetime.utcnow() + (expires_delta or ACCESS_TOKEN_EXPIRE_DELTA)
    to_encode.update({"exp": expire})
    return jwt.encode(to_encode, SECRET_KEY, algorithm=JWT_ALGORITHM)

def decode_token(token: str) -> dict:
    try:
        return jwt.decode(token, SECRET_KEY, algorithms=[JWT_ALGORITHM])
    except JWTError:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid or expired token")
def get_current_user(
    creds: HTTPAuthorizationCredentials = Depends(bearer_scheme),
) -> User:
    token = creds.credentials
    payload = decode_token(token)
    email = payload.get("sub")
    if not email:
        raise HTTPException(status_code=401, detail="Invalid authentication credentials")

    db = SessionLocal()
    try:
        user = db.query(User).filter(User.email == email).first()
        if not user:
            raise HTTPException(status_code=401, detail="User not found")
        return user
    finally:
        db.close()