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
    """
    Logs events like idle_detected, focus_resumed, nudge_shown, etc.
    Also updates research stats for each user.
    """
    event_type = data.get("event_type")
    if not event_type:
        return {"error": "Missing event_type"}

    # 1️⃣ Create base event
    event = models.UserActivity(
        user_id=current_user.id,
        activity_type=event_type,
        extra_data=data.get("details", {}),
    )
    db.add(event)

    # 2️⃣ Ensure stats record
    stats = db.query(models.UserStats).filter_by(user_id=current_user.id).first()
    if not stats:
        stats = models.UserStats(user_id=current_user.id)
        db.add(stats)

    # 3️⃣ Handle metrics updates
    if event_type == "idle_detected":
        stats.idle_count += 1
        # sustained attention
        last_refocus = (
            db.query(models.UserActivity)
            .filter_by(user_id=current_user.id, activity_type="focus_resumed")
            .order_by(models.UserActivity.created_at.desc())
            .first()
        )
        if last_refocus:
            sustained = (datetime.utcnow() - last_refocus.created_at).total_seconds()
            stats.total_sustained_attention += sustained
            db.add(models.UserActivity(
                user_id=current_user.id,
                activity_type="sustained_attention",
                duration_seconds=int(sustained),
                extra_data={"duration": sustained},
            ))

    elif event_type == "nudge_shown":
        stats.total_nudges_shown += 1

    elif event_type == "focus_resumed":
        # immediate refocus detection (within 60s)
        last_nudge = (
            db.query(models.UserActivity)
            .filter_by(user_id=current_user.id, activity_type="nudge_shown")
            .order_by(models.UserActivity.created_at.desc())
            .first()
        )
        if last_nudge:
            delta = (datetime.utcnow() - last_nudge.created_at).total_seconds()
            if delta <= 60:
                stats.total_refocus_within_60s += 1
                db.add(models.UserActivity(
                    user_id=current_user.id,
                    activity_type="immediate_refocus",
                    duration_seconds=int(delta),
                    extra_data={"latency": delta},
                ))

    elif event_type == "session_feedback":
        rating = data.get("details", {}).get("rating", 0)
        total = stats.total_sessions * stats.avg_feedback_score + rating
        stats.total_sessions += 1
        stats.avg_feedback_score = total / stats.total_sessions if stats.total_sessions > 0 else 0

    db.commit()
    print(f"✅ Logged {event_type} for user {current_user.username}")
    return {"message": f"{event_type} logged successfully"}