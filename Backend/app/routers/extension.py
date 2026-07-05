from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from app.database import models
from app.database.db_setup import get_db
from app.services.security import get_current_user

router = APIRouter(prefix="/api/extension", tags=["Extension"])


def default_image_url_for_user(user_id: int) -> str:
    return f"https://picsum.photos/seed/moirai-user-{user_id}/900/600"


@router.post("/ensure-reminder")
def ensure_reminder(
    db: Session = Depends(get_db),
    current_user: models.User = Depends(get_current_user),
):
    reminder = (
        db.query(models.ExtensionReminder)
        .filter(models.ExtensionReminder.user_id == current_user.id)
        .first()
    )

    if reminder is None:
        reminder = models.ExtensionReminder(
            user_id=current_user.id,
            image_url=default_image_url_for_user(current_user.id),
            cue="این یک تصویر تستی برای افزونه است.",
        )
        db.add(reminder)
    else:
        reminder.image_url = default_image_url_for_user(current_user.id)
        reminder.cue = "این یک تصویر تستی برای افزونه است."

    db.commit()
    db.refresh(reminder)

    return {
        "ok": True,
        "user_id": current_user.id,
        "image_url": reminder.image_url,
        "cue": reminder.cue,
    }


@router.get("/active-reminder")
def active_reminder(
    db: Session = Depends(get_db),
    current_user: models.User = Depends(get_current_user),
):
    reminder = (
        db.query(models.ExtensionReminder)
        .filter(models.ExtensionReminder.user_id == current_user.id)
        .first()
    )

    if reminder is None:
        reminder = models.ExtensionReminder(
            user_id=current_user.id,
            image_url=default_image_url_for_user(current_user.id),
            cue="این یک تصویر تستی برای افزونه است.",
        )
        db.add(reminder)
        db.commit()
        db.refresh(reminder)

    return {
        "ok": True,
        "user_id": current_user.id,
        "email": current_user.email,
        "image_url": reminder.image_url,
        "cue": reminder.cue,
    }