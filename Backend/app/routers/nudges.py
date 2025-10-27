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

router = APIRouter(prefix="/nudges", tags=["Nudges"])


@router.get("/next/{user_id}")
def get_next_nudge(
    user_id: int,
    db: Session = Depends(get_db),
    current_user: models.User = Depends(get_current_user),
):
    # Only allow the owner to fetch their nudges
    if current_user.id != user_id:
        raise HTTPException(status_code=403, detail="Not authorized for this user.")

    # Try to fetch a random existing nudge
    nudges = (
        db.query(models.Nudge)
        .filter(models.Nudge.user_id == user_id)
        .order_by(asc(models.Nudge.created_at))
        .all()
    )

    if not nudges:
        raise HTTPException(status_code=404, detail="No nudges found for this user")
    # If none exist, generate one from latest EFT (if available)
        eft = (
            db.query(models.EFTResponse)
            .filter(models.EFTResponse.user_id == user_id)
            .order_by(models.EFTResponse.created_at.desc())
            .first()
        )
        if eft:
            eft_data = {
                "q1_why_goal_matters": eft.q1_why_goal_matters,
                "q2_when_reach_goal": eft.q2_when_reach_goal,
                "q3_possible_obstacles": eft.q3_possible_obstacles,
                "q4_future_visualization": eft.q4_future_visualization,
                "q5_if_give_up": eft.q5_if_give_up,
                "q6_notes": eft.q6_notes,
            }
            prompt_text, nudge_text = generate_nudge(
                eft_data,
                user_name=current_user.full_name_fa or current_user.username,
                english_goal=current_user.english_goal,
            )

            # store prompt + nudge for future reuse
            prompt = models.AIPrompt(
                user_id=current_user.id,
                model_name="gpt-4o-mini",
                prompt_text=prompt_text,
                purpose="nudge_generation",
                response_preview=nudge_text,
            )
            db.add(prompt)
            db.commit()
            db.refresh(prompt)

            nudge = models.Nudge(
                user_id=current_user.id,
                type="positive",
                source="ai",
                text=nudge_text,
                related_prompt_id=prompt.id,
            )
            db.add(nudge)
            db.commit()
            db.refresh(nudge)
            return {"nudge": nudge.text, "source": nudge.source, "id": nudge.id}

        # No EFT either → safe fallback
        fallback = "چرا شروع کردی را به خاطر بیاور — هر دقیقه مطالعه تو را به هدف آیلتس نزدیک‌تر می‌کند."
        return {"nudge": fallback, "source": "fallback", "id": None}
    
    # 2️⃣ Check if user has a record of the last shown nudge
    last_event = (
        db.query(models.EventLog)
        .filter(models.EventLog.user_id == user_id, models.EventLog.event_type == "nudge_shown")
        .order_by(models.EventLog.created_at.desc())
        .first()
    )

    if last_event and "nudge_id" in (last_event.details or {}):
        last_nudge_id = last_event.details["nudge_id"]
        current_index = next((i for i, n in enumerate(nudges) if n.id == last_nudge_id), -1)
        next_index = (current_index + 1) % len(nudges)
    else:
        next_index = 0  # first time use

    next_nudge = nudges[next_index]

    # 3️⃣ Log that this nudge was shown
    event = models.EventLog(
        user_id=user_id,
        event_type="nudge_shown",
        details={"nudge_id": next_nudge.id, "timestamp": datetime.utcnow().isoformat()},
    )
    db.add(event)
    db.commit()

    print(f"💬 Served nudge #{next_index + 1}/{len(nudges)} for {current_user.username}: {next_nudge.text[:50]}...")

    return {"nudge_id": next_nudge.id, "nudge": next_nudge.text}


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