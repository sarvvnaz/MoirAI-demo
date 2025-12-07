# # app/api/sessions.py  (or similar)
# from fastapi import APIRouter, Depends, status
# from sqlalchemy.orm import Session
# from datetime import datetime
# from sqlalchemy import func

# from app.database.db_setup import get_db
# from app.database import models
# from app.services.security import get_current_user

# router = APIRouter(prefix="/sessions", tags=["Sessions"])


# # ──────────────────────────────────────────────────────────────────────────────
# # Session helper
# # ──────────────────────────────────────────────────────────────────────────────
# @router.post("/session/start", status_code=status.HTTP_201_CREATED)
# def get_or_create_current_session(db: Session, user_id: int) -> models.Session:
#   """
#   Returns the latest open session (ended_at IS NULL) for a user.
#   If none exists, create a new one with the next session_number.
#   """
#   session = (
#       db.query(models.Session)
#       .filter(
#           models.Session.user_id == user_id,
#           models.Session.ended_at.is_(None),
#       )
#       .order_by(models.Session.started_at.desc())
#       .first()
#   )

#   if session is not None:
#     return session

#   # No open session → create a new one
#   last_number = (
#       db.query(func.coalesce(func.max(models.Session.session_number), 0))
#       .filter(models.Session.user_id == user_id)
#       .scalar()
#   )
#   next_number = last_number + 1

#   session = models.Session(
#       user_id=user_id,
#       session_number=next_number,
#       started_at=datetime.utcnow(),
#   )
#   db.add(session)
#   db.flush()  # assign ID

#   return session

# def get_open_session(db: Session, user_id: int) -> models.Session | None:
#     """
#     Returns the latest open session (ended_at IS NULL) for a user,
#     or None if there is no active session.
#     """
#     return (
#         db.query(models.Session)
#         .filter(
#             models.Session.user_id == user_id,
#             models.Session.ended_at.is_(None),
#         )
#         .order_by(models.Session.started_at.desc())
#         .first()
#     )
# @router.post("/session/start", status_code=status.HTTP_201_CREATED)
# def start_session(
#     db: Session = Depends(get_db),
#     current_user: models.User = Depends(get_current_user),
# ):
#     """
#     Explicitly start (or reuse) a session when a task page is opened.
#     """
#     user_id = current_user.id
#     session = get_or_create_current_session(db, user_id)
#     db.commit()  # in case it was newly created

#     return {
#       "session_id": session.id,
#       "session_number": session.session_number,
#       "started_at": session.started_at.isoformat(),
#     }


# @router.post("/end_session", status_code=status.HTTP_200_OK)
# def end_session(
#     db: Session = Depends(get_db),
#     current_user: models.User = Depends(get_current_user),
# ):
#     """Marks the user's current open session as ended."""
#     user_id = current_user.id

#     # Find the active session
#     session = (
#         db.query(models.Session)
#         .filter(models.Session.user_id == user_id, models.Session.ended_at.is_(None))
#         .first()
#     )

#     if not session:
#         return {"message": "No active session to end."}

#     session.ended_at = datetime.utcnow()
#     db.commit()

#     print(f"🟢 Session {session.session_number} closed for user {user_id}")

#     return {"message": "Session ended successfully"}
