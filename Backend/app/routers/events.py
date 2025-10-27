from fastapi import APIRouter, Depends, status
from sqlalchemy.orm import Session
from datetime import datetime
from app.database.db_setup import get_db
from app.database import models
from app.services.security import get_current_user

router = APIRouter(prefix="/events", tags=["Events"])


@router.post("/nudge_shown", status_code=status.HTTP_201_CREATED)
def log_nudge_shown_event(
    event: dict,
    db: Session = Depends(get_db),
    current_user: models.User = Depends(get_current_user),
):
    """Triggered when a nudge is shown due to inactivity"""
    nudge_id = event.get("nudge_id")
    if not nudge_id:
        return {"error": "Missing nudge_id"}

    log = models.EventLog(
        user_id=current_user.id,
        event_type="nudge_shown",
        details={"nudge_id": nudge_id, "timestamp": datetime.utcnow().isoformat()},
    )
    db.add(log)
    db.commit()
    print(f"📋 Logged event: Nudge shown (nudge_id={nudge_id}) for user {current_user.username}")
    return {"message": "Nudge event logged successfully."}


@router.post("/focus_resumed", status_code=status.HTTP_201_CREATED)
def log_focus_resumed_event(
    db: Session = Depends(get_db),
    current_user: models.User = Depends(get_current_user),
):
    """Triggered when user returns focus after being idle"""
    log = models.EventLog(
        user_id=current_user.id,
        event_type="focus_resumed",
        details={"timestamp": datetime.utcnow().isoformat()},
    )
    db.add(log)
    db.commit()
    print(f"📋 Logged event: Focus resumed for user {current_user.username}")
    return {"message": "Focus resumed event logged successfully."}

@router.post("/log", status_code=status.HTTP_201_CREATED)
def log_generic_event(
    data: dict,
    db: Session = Depends(get_db),
    current_user: models.User = Depends(get_current_user),
):
    """Generic event logger for activity, idle, or focus events"""
    event_type = data.get("event_type")
    if not event_type:
        return {"error": "Missing event_type"}

    event = models.UserActivity(
        user_id=current_user.id,
        activity_type=event_type,
        extra_data=data.get("details", {}),
    )
    db.add(event)
    db.commit()
    print(f"📋 Logged event: {event_type} for user {current_user.username}")
    return {"message": f"{event_type} logged successfully"}
