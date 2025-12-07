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





@router.get("/{user_id}/{nudge_id}", status_code=status.HTTP_200_OK)
def get_and_increment_nudge(
    user_id: int,
    nudge_id: int,
    db: Session = Depends(get_db),
    current_user: models.User = Depends(get_current_user)
):
    # 🧠 ensure this user can access only their own nudges
    if current_user.id != user_id:
        raise HTTPException(status_code=403, detail="Not authorized")

    # 🧩 fetch nudges for user
    nudges = (
        db.query(models.Nudge)
        .filter(models.Nudge.user_id == user_id)
        .order_by(models.Nudge.id.asc())
        .all()
    )
    if not nudges:
        raise HTTPException(status_code=404, detail="No nudges found")

    # 🧮 find current nudge in list
    current_index = next((i for i, n in enumerate(nudges) if n.id == nudge_id), None)
    if current_index is None:
        raise HTTPException(status_code=404, detail=f"Nudge {nudge_id} not found")

    current_nudge = nudges[current_index]
    next_index = (current_index + 1) % len(nudges)
    next_nudge = nudges[next_index]

    # 🧾 log the event
    db.add(models.EventLog(
        user_id=user_id,
        event_type="nudge_shown",
        details={"nudge_id": current_nudge.id, "timestamp": datetime.utcnow().isoformat()},
    ))
    db.commit()

    print(f"💬 Served nudge #{current_index + 1}/{len(nudges)} for {current_user.id}: {current_nudge.text[:60]}…")

    return {
        "id": current_nudge.id,
        "type": current_nudge.type,
        "message": current_nudge.text.strip(),
        "next_nudge_id": next_nudge.id
    }
