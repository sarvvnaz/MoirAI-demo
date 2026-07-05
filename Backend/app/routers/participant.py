"""Participant routes for baseline/demographics collection.

This module defines a simple endpoint for saving a participant's
baseline demographic and study context information. It creates or
updates a ParticipantProfile record tied to the current user.
"""

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from app.database.db_setup import get_db
from app.database import models
from app.services.security import get_current_user

router = APIRouter(prefix="/api/participant", tags=["Participant"])


@router.post("/profile", status_code=status.HTTP_200_OK)
def save_profile(
    data: dict,
    db: Session = Depends(get_db),
    current_user: models.User = Depends(get_current_user),
):
    """
    Create or update the participant's baseline profile. The request body
    should contain keys corresponding to the ParticipantProfile fields:

    - age
    - education_level
    - study_field
    - english_goal
    - english_level
    - study_frequency
    - english_importance

    If a profile already exists for the user, the record is updated; otherwise
    a new one is created.
    """
    if current_user is None:
        raise HTTPException(status_code=401, detail="Unauthorized")

    # Find existing profile, if any
    profile = (
        db.query(models.ParticipantProfile)
        .filter(models.ParticipantProfile.user_id == current_user.id)
        .first()
    )

    if profile is None:
        profile = models.ParticipantProfile(user_id=current_user.id)
        db.add(profile)

    # Update fields if present; missing fields leave prior values unchanged
    profile.age = data.get("age", profile.age)
    profile.education_level = data.get("education_level", profile.education_level)
    profile.study_field = data.get("study_field", profile.study_field)
    profile.english_goal = data.get("english_goal", profile.english_goal)
    profile.english_level = data.get("english_level", profile.english_level)
    profile.study_frequency = data.get("study_frequency", profile.study_frequency)
    profile.english_importance = data.get(
        "english_importance", profile.english_importance
    )

    db.commit()
    db.refresh(profile)

    return {"ok": True}
