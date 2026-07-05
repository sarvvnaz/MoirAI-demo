# eft.py
import json
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from app.database import models
from app.database.db_setup import get_db
from app.services.ai_service import generate_nudge
from app.services.eft_chat_service import EFTChatService
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
        timeFrame=data.get("timeFrame"),
        place=data.get("place"),
        activities=data.get("activities"),
        people=data.get("people"),
        feelings=data.get("feelings"),
    )
    db.add(eft)
    db.commit()
    db.refresh(eft)

    # Generate + parse + save nudges
    saved_msgs: list[str] = []
    
    existing_count = db.query(models.Nudge).filter(
    models.Nudge.user_id == current_user.id
).count()

    for i in range(2): # Generate 2 sets of nudges
        try:
            _, raw = generate_nudge(
                data,
                user_name=current_user.full_name_fa,
                exam_goal=current_user.examGoal or "موفقیت در زبان انگلیسی",
                
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

# ----------------------------------------------------------------------------
# New endpoint: save structured episode
# ----------------------------------------------------------------------------
@router.post("/episode", status_code=status.HTTP_201_CREATED)
def save_eft_episode(
    data: dict,
    db: Session = Depends(get_db),
    current_user: models.User = Depends(get_current_user),
):
    """
    Saves a structured EFT episode for the current user. The request body
    should include an `episode` field containing the episode JSON object.

    Example request body:
      {
        "episode": {
          ... as defined in the frontend episode schema ...
        }
      }

    The episode is stored as a JSON string in the EFTEpisode table.
    """
    if current_user is None:
        raise HTTPException(status_code=401, detail="Unauthorized")

    episode_data = data.get("episode")
    if episode_data is None:
        raise HTTPException(status_code=422, detail="Missing episode data")

    try:
        # Serialise to JSON string to persist
        import json as _json
        episode_json_str = _json.dumps(episode_data, ensure_ascii=False)
    except Exception as e:
        raise HTTPException(status_code=422, detail=f"Invalid episode JSON: {e}")

    episode = models.EFTEpisode(
        user_id=current_user.id,
        episode_json=episode_json_str,
    )
    db.add(episode)
    db.commit()
    db.refresh(episode)

    return {"ok": True, "episode_id": episode.id}


# ----------------------------------------------------------------------------
# Backend-driven EFT chat
# ----------------------------------------------------------------------------
@router.post("/chat", status_code=status.HTTP_200_OK)
def eft_chat(
    data: dict,
    db: Session = Depends(get_db),
    current_user: models.User = Depends(get_current_user),
):
    if current_user is None:
        raise HTTPException(status_code=401, detail="Unauthorized")

    message = data.get("message")
    client_version = data.get("client_version", "")
    reset = bool(data.get("reset", False))

    service = EFTChatService(db, current_user.id)
    result = service.process_message(message, client_version=client_version, reset=reset)
    db.commit()
    return result


@router.post("/reset", status_code=status.HTTP_200_OK)
def eft_chat_reset(
    db: Session = Depends(get_db),
    current_user: models.User = Depends(get_current_user),
):
    if current_user is None:
        raise HTTPException(status_code=401, detail="Unauthorized")

    service = EFTChatService(db, current_user.id)
    service._reset_state()
    first = service._ask_question(1, {})
    db.commit()
    return {
        "bot": first,
        "step": 1,
        "needs_user": True,
        "can_start_session": False,
        "episode_summary": None,
    }
