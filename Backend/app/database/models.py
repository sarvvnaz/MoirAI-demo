from __future__ import annotations
from datetime import datetime
from typing import Optional, Literal
from sqlalchemy import (
    String, Integer, Float, DateTime, func, ForeignKey, Text, JSON, Enum, Index, Column
)
from sqlalchemy.orm import Mapped, mapped_column, relationship
from .db_setup import Base

# ─────────────────────────────
# USER
# ─────────────────────────────
class User(Base):
    __tablename__ = "users"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, index=True)
    username: Mapped[str] = mapped_column(String(100), unique=True, index=True, nullable=False)
    full_name_fa: Mapped[Optional[str]] = mapped_column(String(100), nullable=True)
    email: Mapped[Optional[str]] = mapped_column(String(255), unique=True, index=True)
    password_hash: Mapped[str] = mapped_column(String(255), nullable=False)
    english_goal: Mapped[Optional[str]] = mapped_column(String(100), nullable=True)  # e.g. IELTS 7.5
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=False), default=datetime.utcnow)

    # Relations
    eft_response: Mapped[Optional["EFTResponse"]] = relationship(
        back_populates="user", uselist=False, cascade="all, delete-orphan"
    )
    ai_prompts: Mapped[list["AIPrompt"]] = relationship(
        back_populates="user", cascade="all, delete-orphan"
    )
    nudges: Mapped[list["Nudge"]] = relationship(
        back_populates="user", cascade="all, delete-orphan"
    )
    activities: Mapped[list["UserActivity"]] = relationship(
        back_populates="user", cascade="all, delete-orphan"
    )

    def __repr__(self):
        return f"<User {self.username!r} goal={self.english_goal!r}>"


# ─────────────────────────────
# EFT RESPONSE (Persian form)
# ─────────────────────────────
class EFTResponse(Base):
    __tablename__ = "eft_responses"
    __table_args__ = (Index("ix_eft_user_created", "user_id", "created_at"),)

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), nullable=False)

    q1_why_goal_matters: Mapped[Optional[str]] = mapped_column(Text)
    q2_when_reach_goal: Mapped[Optional[str]] = mapped_column(Text)
    q3_possible_obstacles: Mapped[Optional[str]] = mapped_column(Text)
    q4_future_visualization: Mapped[Optional[str]] = mapped_column(Text)
    q5_if_give_up: Mapped[Optional[str]] = mapped_column(Text)
    q6_notes: Mapped[Optional[str]] = mapped_column(Text)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)

    user: Mapped["User"] = relationship(back_populates="eft_response")

    def __repr__(self):
        return f"<EFTResponse user_id={self.user_id}>"


# ─────────────────────────────
# AI PROMPTS (Prompt storage for reproducibility)
# ─────────────────────────────
class AIPrompt(Base):
    """
    Stores the actual text prompts used to generate nudges for a user.
    Keeping them allows analysis and reproducibility of AI behavior.
    """
    __tablename__ = "ai_prompts"
    __table_args__ = (Index("ix_prompt_user_created", "user_id", "created_at"),)

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
    model_name: Mapped[str] = mapped_column(String(100), default="gpt-4o-mini")
    prompt_text: Mapped[str] = mapped_column(Text, nullable=False)
    purpose: Mapped[str] = mapped_column(String(64), default="nudge_generation")  # or 'goal_summary', etc.
    response_preview: Mapped[Optional[str]] = mapped_column(Text, nullable=True)
    metadata_json: Mapped[Optional[dict]] = mapped_column(JSON, nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)

    user: Mapped["User"] = relationship(back_populates="ai_prompts")

    def __repr__(self):
        return f"<AIPrompt id={self.id} user_id={self.user_id} purpose={self.purpose}>"


# ─────────────────────────────
# NUDGES
# ─────────────────────────────
NudgeType = Literal["positive", "negative"]
NudgeSource = Literal["ai", "manual"]

class Nudge(Base):
    __tablename__ = "nudges"
    __table_args__ = (Index("ix_nudge_user_created", "user_id", "created_at"),)

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
    type: Mapped[str] = mapped_column(Enum("positive", "negative", name="nudge_type"), nullable=False)
    source: Mapped[str] = mapped_column(Enum("ai", "manual", name="nudge_source"), default="ai")
    text: Mapped[str] = mapped_column(Text, nullable=False)
    related_prompt_id: Mapped[Optional[int]] = mapped_column(
        ForeignKey("ai_prompts.id", ondelete="SET NULL"), nullable=True
    )
    context: Mapped[Optional[dict]] = mapped_column(JSON)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)

    user: Mapped["User"] = relationship(back_populates="nudges")
    prompt: Mapped[Optional["AIPrompt"]] = relationship()

    def __repr__(self):
        return f"<Nudge {self.type} user_id={self.user_id}>"


# ─────────────────────────────
# USER ACTIVITY (UK - activity/performance tracking)
# ─────────────────────────────
class UserActivity(Base):
    """
    Tracks user sessions, focus/idle, reading, quiz performance, etc.
    Will be useful when linking with eye-tracking or attention data.
    """
    __tablename__ = "user_activity"
    __table_args__ = (Index("ix_activity_user_created", "user_id", "created_at"),)

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), nullable=False)

    activity_type: Mapped[str] = mapped_column(String(64), nullable=False)  # e.g. "reading", "idle_detected", "focus_resumed", "nudge_shown"
    duration_seconds: Mapped[Optional[int]] = mapped_column(Integer, nullable=True)
    performance_score: Mapped[Optional[float]] = mapped_column(Integer, nullable=True)  # e.g. quiz result or comprehension
    extra_data: Mapped[Optional[dict]] = mapped_column(JSON, nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)

    user: Mapped["User"] = relationship(back_populates="activities")

    def __repr__(self):
        return f"<UserActivity user_id={self.user_id} type={self.activity_type}>"



# ─────────────────────────────
# EVENT LOG
# ─────────────────────────────
class EventLog(Base):
    __tablename__ = "event_log"

    id = Column(Integer, primary_key=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    event_type = Column(String, index=True)
    timestamp = Column(DateTime(timezone=True), server_default=func.now())
    details = Column(JSON, nullable=True)


class UserStats(Base):
    __tablename__ = "user_stats"

    id = Column(Integer, primary_key=True)
    user_id = Column(Integer, ForeignKey("users.id"), unique=True, nullable=False)
    idle_count = Column(Integer, default=0)
    distraction_count = Column(Integer, default=0)
    total_sustained_attention = Column(Float, default=0.0)
    total_refocus_within_60s = Column(Integer, default=0)
    total_nudges_shown = Column(Integer, default=0)
    total_sessions = Column(Integer, default=0)
    avg_feedback_score = Column(Float, default=0.0)