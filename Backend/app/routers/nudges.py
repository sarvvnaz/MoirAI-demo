from __future__ import annotations
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import func
from sqlalchemy.orm import Session
from sqlalchemy import asc, desc
from datetime import datetime
from app.database.db_setup import get_db
from app.database import models
from app.services.security import get_current_user
from app.services.ai_service import generate_nudge

router = APIRouter(prefix="/api/nudges", tags=["Nudges"])



@router.get("/next/{user_id}")

@router.put("/{nudge_id}", status_code=status.HTTP_200_OK)
def edit_nudge(
    nudge_id: int,
    data: dict,
    db: Session = Depends(get_db),
    current_user: models.User = Depends(get_current_user)
):
    nudge = db.query(models.Nudge).filter_by(id=nudge_id, user_id=current_user.id).first()
    if not nudge:
        raise HTTPException(status_code=404, detail="Nudge not found")

    nudge.text = data.get("text", nudge.text)
    db.commit()
    db.refresh(nudge)
    return {"message": "Nudge updated successfully", "nudge": {"id": nudge.id, "text": nudge.text}}





@router.get("/{user_id}/{nudge_number}", status_code=status.HTTP_200_OK)
def get_and_increment_nudge(
    user_id: int,
    nudge_number: int,
    db: Session = Depends(get_db),
    current_user: models.User = Depends(get_current_user)
):
    # 🔒 1. Ensure user is accessing their own nudges
    if current_user.id != user_id:
        raise HTTPException(status_code=403, detail="Not authorized")

    # 📥 2. Fetch all nudges for this user
    nudges = (
        db.query(models.Nudge)
        .filter(models.Nudge.user_id == user_id)
        .order_by(models.Nudge.nudge_number.asc())
        .all()
    )

    if not nudges:
        raise HTTPException(status_code=404, detail="No nudges found")

    # ❌ invalid request (index out of range)
    if nudge_number < 0 or nudge_number >= len(nudges):
        raise HTTPException(
            status_code=404,
            detail=f"Nudge {nudge_number} not found for this user"
        )

    # 🎯 3. Get current nudge
    current_nudge = nudges[nudge_number]

    # 🔁 4. Determine next nudge (cycle to 0)
    next_nudge_number = (nudge_number + 1) % len(nudges)

    # 📝 5. Log event
    db.add(models.EventLog(
        user_id=user_id,
        event_type="nudge_shown",
        details={
            "nudge_number": current_nudge.nudge_number,
            "timestamp": datetime.utcnow().isoformat()
        }
    ))
    db.commit()

    print(
        f"💬 Served nudge {current_nudge.nudge_number}/{len(nudges)-1} "
        f"for user={current_user.id}: {current_nudge.text[:60]}..."
    )

    # 📤 6. Return response
    return {
        "nudge_number": current_nudge.nudge_number,
        "message": current_nudge.text.strip(),
        "type": current_nudge.type,
        "next_nudge_number": next_nudge_number
    }