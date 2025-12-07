from __future__ import annotations
from datetime import datetime
from typing import Optional, Literal
import uuid
from pydantic import EmailStr

from sqlalchemy import (
    String, Integer, Float, DateTime, func, ForeignKey, Text, JSON, Enum, Index, Column, UniqueConstraint
)
from sqlalchemy.orm import Mapped, mapped_column, relationship
from .base_class import Base
# ─────────────────────────────
# USER

class User(Base):
    __tablename__ = "users"
    id: Mapped[int] = mapped_column(
        Integer,
        primary_key=True,
        index=True,
        autoincrement=True
    )
    email: Mapped[EmailStr] = mapped_column(String(255), nullable=False, index=True)
    full_name_fa: Mapped[str] = mapped_column(String(100), nullable=False, index=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=func.now())

    __table_args__ = (
        UniqueConstraint("email", name="uq_users_email"),
    )
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
    stats: Mapped["UserStats"] = relationship(
        back_populates="user", uselist=False, cascade="all, delete-orphan"
    )
    sessions: Mapped[list["Session"]] = relationship(
        back_populates="user", cascade="all, delete-orphan"
    )


    def __repr__(self):
        return f"<User {self.email!r} name={self.full_name_fa!r}>"


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
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=func.now())


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
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=func.now())


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
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=func.now())


    user: Mapped["User"] = relationship(back_populates="nudges")
    prompt: Mapped[Optional["AIPrompt"]] = relationship()

    def __repr__(self):
        return f"<Nudge {self.type} user_id={self.user_id}>"


# ─────────────────────────────
# USER ACTIVITY (UK - activity/performance tracking)
# ─────────────────────────────
class UserActivity(Base):
    """
    Tracks all granular user events (reading, idle, focus, nudge, etc.)
    Useful for fine-grained behavioral timelines.
    """
    __tablename__ = "user_activity"
    __table_args__ = (Index("ix_activity_user_created", "user_id", "created_at"),)

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
    activity_type: Mapped[str] = mapped_column(String(64), nullable=False)
    duration_seconds: Mapped[Optional[int]] = mapped_column(Integer, nullable=True)
    performance_score: Mapped[Optional[float]] = mapped_column(Float, nullable=True)
    extra_data: Mapped[Optional[dict]] = mapped_column(JSON, nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=func.now())


    user: Mapped["User"] = relationship(back_populates="activities")

    def __repr__(self):
        return f"<UserActivity user_id={self.user_id} type={self.activity_type}>"




# ─────────────────────────────
# EVENT LOG
# ─────────────────────────────
class EventLog(Base):
    """
    Stores raw frontend/backend system events.
    More generic than UserActivity — includes internal triggers and feedback events.
    """
    __tablename__ = "event_log"

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
    event_type: Mapped[str] = mapped_column(String(64), index=True, nullable=False)
    timestamp: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=func.now())
    details: Mapped[Optional[dict]] = mapped_column(JSON, nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=func.now())
    user: Mapped["User"] = relationship(back_populates="event_logs")

    def __repr__(self):
        return f"<EventLog user_id={self.user_id} type={self.event_type}>"

# Add reverse relationship to User
User.event_logs = relationship("EventLog", back_populates="user", cascade="all, delete-orphan")


# ─────────────────────────────
# USER STATS (AGGREGATED METRICS)
# ─────────────────────────────

class UserStats(Base):
    __tablename__ = "user_stats"

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    user_id: Mapped[int] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"), index=True
    )

    total_idle_count: Mapped[int] = mapped_column(Integer, nullable=False, default=0)
    total_distraction_count: Mapped[int] = mapped_column(Integer, nullable=False, default=0)
    total_sustained_attention: Mapped[int] = mapped_column(Integer, nullable=False, default=0)
    total_refocus_within_60s: Mapped[int] = mapped_column(Integer, nullable=False, default=0)
    total_nudges_shown: Mapped[int] = mapped_column(Integer, nullable=False, default=0)
    total_sessions: Mapped[int] = mapped_column(Integer, nullable=False, default=0)
    avg_feedback_score: Mapped[float] = mapped_column(Float, nullable=False, default=0.0)

    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now()
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), onupdate=func.now()
    )

    user: Mapped["User"] = relationship(back_populates="stats")


class Session(Base):
    """
    One focused work / study session for a user.
    Stores per-session metrics; UserStats will aggregate from here.
    """
    __tablename__ = "sessions"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, index=True)
    user_id: Mapped[int] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"), index=True
    )

    session_number: Mapped[int] = mapped_column(Integer, nullable=False)

    # timestamps
    started_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now()
    )
    ended_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True), nullable=True
    )

    # per-session stats (same “shape” as UserStats but per session)
    idle_count: Mapped[int] = mapped_column(Integer, nullable=False, default=0)
    distraction_count: Mapped[int] = mapped_column(Integer, nullable=False, default=0)
    sustained_attention: Mapped[int] = mapped_column(Integer, nullable=False, default=0)
    refocus_within_60s: Mapped[int] = mapped_column(Integer, nullable=False, default=0)
    nudges_shown: Mapped[int] = mapped_column(Integer, nullable=False, default=0)
    # feedback for each couple of sessions
    feedback_score: Mapped[float] = mapped_column(Float, nullable=False, default=0.0)
    feedback_comment = mapped_column(Text, nullable=False, default="")

    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now()
    )

    user: Mapped["User"] = relationship(back_populates="sessions")


__all__ = ["User", "UserActivity", "EventLog", "UserStats", "Session"]
