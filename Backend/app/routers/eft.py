from fastapi import APIRouter, Depends, status, HTTPException
from sqlalchemy.orm import Session
from app.database.db_setup import get_db
from app.database import models
from app.services.ai_service import generate_nudge
from app.services.security import get_current_user

router = APIRouter(prefix="/eft", tags=["EFT"])


@router.post("/submit", status_code=status.HTTP_200_OK)
def submit_eft(
    data: dict,
    db: Session = Depends(get_db),
    current_user: models.User = Depends(get_current_user)
):
    """
    Save user's EFT reflection, generate two Persian motivational nudges,
    and store both in the database.
    """
    if not current_user:
        raise HTTPException(status_code=401, detail="Unauthorized")

    # ✅ Save EFT response
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

    # ✅ Generate two new Persian nudges
    nudges_text = []
    for i in range(2):
        try:
            prompt_text, nudge_text = generate_nudge(
                data,
                user_name=current_user.full_name_fa or current_user.username,
                english_goal=current_user.english_goal,
            )
            nudges_text.append(nudge_text)

            # Save each nudge to DB
            nudge = models.Nudge(
                user_id=current_user.id,
                type="positive",
                source="ai",
                text=nudge_text,
            )
            db.add(nudge)
            print(f"✅ Generated nudge {i+1}: {nudge_text}")

        except Exception as e:
            print(f"⚠️ Error generating nudge {i+1}: {e}")

    db.commit()

    return {
        "message": "EFT responses and Persian nudges saved successfully.",
        "nudges": nudges_text
    }
