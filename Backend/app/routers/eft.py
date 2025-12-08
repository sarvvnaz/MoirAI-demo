# eft.py
import json
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from app.database import models
from app.database.db_setup import get_db
from app.services.ai_service import generate_nudge
from app.services.security import get_current_user
from app.utils.nudge_parser import extract_nudge_messages  

router = APIRouter(prefix="/api/eft", tags=["EFT"])

@router.post("/submit", status_code=status.HTTP_200_OK)
def submit_eft(
    data: dict,
    db: Session = Depends(get_db),
    current_user: models.User = Depends(get_current_user)
):
    if not current_user:
        raise HTTPException(status_code=401, detail="Unauthorized")

    # Save EFT
    eft = models.EFTResponse(
        user_id=current_user.id,
        q1_why_goal_matters=data.get("q1_why_goal_matters"),
        q2_when_reach_goal=data.get("q2_when_reach_goal"),
        q3_possible_obstacles=data.get("q3_possible_obstacles"),
        q4_future_visualization=data.get("q4_future_visualization"),
        q5_if_give_up=data.get("q5_if_give_up"),
        q6_notes=data.get("q6_notes"),
    )
    db.add(eft)
    db.commit()
    db.refresh(eft)

    # Generate + parse + save nudges
    saved_msgs: list[str] = []
    
    existing_count = db.query(models.Nudge).filter(
    models.Nudge.user_id == current_user.id
).count()

    for i in range(2):
        try:
            _, raw = generate_nudge(
                data,
                user_name=current_user.full_name_fa,
                
            )

            msgs = extract_nudge_messages(raw)
            if not msgs:
                print(f"⚠️ Could not parse nudge {i+1}: not valid JSON.")
                continue
            print(f"💡 Parsed {msgs} messages from nudge set {i+1}")

            for index, msg in enumerate(msgs):
                db.add(models.Nudge(
                    user_id=current_user.id,
                    nudge_number=existing_count + index,
                    type="positive",   # or detect from parsed JSON if you prefer
                    source="ai",
                    text=msg,          # <-- only the message text
                ))
                saved_msgs.append(msg)

            print(f"✅ Stored {len(msgs)} messages from nudge set {i+1}")
            existing_count += len(msgs)

        except Exception as e:
            print(f"⚠️ Error generating nudge {i+1}: {e}")

    db.commit()

    return {"message": "EFT saved. Nudges parsed & stored.", "nudges": saved_msgs}
