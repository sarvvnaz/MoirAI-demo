"""
Backend-driven EFT chatbot scaffold (FSM + light heuristics).

Deterministic FSM:
1) date (6–12 months ahead)
2) place (inside/outside + object in front)
3) action in English
4) people/audience
5) sensory (hear/see)
6) emotion + body signal
7) identity + behavioral evidence
8) lock summary + confirm

LLM is used ONLY as a "wording engine" (optional). If OPENAI_API_KEY is not
configured, the service falls back to short canned Persian prompts.
"""

from __future__ import annotations

import json
import os
import re
from dataclasses import dataclass
from datetime import datetime
from typing import Any, Dict, Optional, Tuple

from sqlalchemy.orm import Session

from app.database import models

try:
    from openai import OpenAI  # type: ignore
except Exception:  # pragma: no cover
    OpenAI = None  # type: ignore


# ----------------------------
# Config
# ----------------------------
DEFAULT_MODEL = os.getenv("OPENAI_MODEL", "gpt-4o-mini")
DEFAULT_TEMPERATURE = float(os.getenv("OPENAI_TEMPERATURE", "0.3"))
DEV_MODE = os.getenv("EFT_DEBUG", "0").lower() in ("1", "true", "yes")


# ----------------------------
# Step keys
# ----------------------------
STEP_KEYS = {
    1: "future_date",
    2: "place",
    3: "action",
    4: "people",
    5: "sensory",
    6: "emotion_body",
    7: "identity",
}


GENERIC_WORDS = [
    "موفق", "موفقیت", "خوشحال", "عالی", "خوب", "روان", "قوی", "fluent", "confident",
]

NOT_SURE_WORDS = [
    "نمی‌دانم", "نمیدانم", "نمی دونم", "not sure", "بی‌نظر", "بی نظر",
]

CONFIRM_WORDS = ["تایید", "تأیید", "تایید می‌کنم", "تایید میکنم", "yes", "ok", "باشه"]
EDIT_WORDS = ["ویرایش", "اصلاح", "تغییر", "دوباره", "edit"]


@dataclass
class ChatResult:
    bot: str
    step: int
    needs_user: bool
    can_start_session: bool
    episode_summary: Optional[str] = None
    debug: Optional[Dict[str, Any]] = None


class EFTChatService:
    def __init__(self, db: Session, user_id: int):
        self.db = db
        self.user_id = user_id

        self._client = None
        api_key = os.getenv("OPENAI_API_KEY")
        if api_key and OpenAI is not None:
            try:
                self._client = OpenAI(api_key=api_key)
            except Exception:
                self._client = None

    # ----------------------------
    # State
    # ----------------------------
    def _get_or_create_state(self) -> models.EFTChatState:
        state = (
            self.db.query(models.EFTChatState)
            .filter(models.EFTChatState.user_id == self.user_id)
            .one_or_none()
        )
        if state is None:
            state = models.EFTChatState(
                user_id=self.user_id,
                current_step=1,
                fields_json=json.dumps({}, ensure_ascii=False),
            )
            self.db.add(state)
            self.db.flush()
        return state

    def _reset_state(self) -> models.EFTChatState:
        state = (
            self.db.query(models.EFTChatState)
            .filter(models.EFTChatState.user_id == self.user_id)
            .one_or_none()
        )
        if state is not None:
            self.db.delete(state)
            self.db.flush()
        state = models.EFTChatState(
            user_id=self.user_id,
            current_step=1,
            fields_json=json.dumps({}, ensure_ascii=False),
        )
        self.db.add(state)
        self.db.flush()
        return state

    # ----------------------------
    # LLM wording engine
    # ----------------------------
    def _llm(self, system: str, user: str, max_tokens: int = 140) -> Optional[str]:
        if not self._client:
            return None
        try:
            resp = self._client.chat.completions.create(
                model=DEFAULT_MODEL,
                temperature=DEFAULT_TEMPERATURE,
                max_tokens=max_tokens,
                messages=[
                    {"role": "system", "content": system},
                    {"role": "user", "content": user},
                ],
            )
            msg = resp.choices[0].message.content or ""
            msg = msg.strip()
            return msg or None
        except Exception:
            return None

    def _system_prompt(self) -> str:
        return (
            "تو یک دستیار پژوهشی دوستانه و کوتاه‌گو هستی که به فارسی گفتگو می‌کنی. "
            "هدف: کمک به کاربر برای ساختن یک اپیزود آینده‌نگر (۶ تا ۱۲ ماه بعد) که در آن انگلیسی مهم است. "
            "قواعد: یک سوال کوتاه در هر پیام، بدون شماره‌گذاری، بدون سخنرانی انگیزشی، بدون درمان/تراپی. "
            "اگر پاسخ کلی یا کوتاه بود، فقط یک بار درخواست جزئیات بده. اگر هنوز کلی بود، دو مثال خیلی کوتاه بده و از کاربر بخواه یکی را انتخاب/تطبیق دهد. "
            "حتماً به چیزهایی که کاربر قبلاً گفته اشاره کن تا گفتگو طبیعی باشد."
        )

    # ----------------------------
    # Validation heuristics
    # ----------------------------
    def _too_short_or_generic(self, s: str) -> bool:
        t = s.strip()
        if len(t) < 24:
            return True
        if len(t.split()) < 6:
            return True
        low = t.lower()
        if any(w in t for w in GENERIC_WORDS) or any(w in low for w in ["confident", "fluent"]):
            # generic words are allowed only if there is also a concrete detail
            # heuristic: requires at least one comma/ "مثلا" / a concrete noun marker
            if not any(x in t for x in ["مثلاً", "مثلا", "مثل", "کنار", "روی", "جلوی", "روبرو", "مقابل"]):
                return True
        return False

    def _validate_step(self, step: int, answer: str) -> Tuple[bool, str]:
        a = answer.strip()
        if self._too_short_or_generic(a):
            return False, "too_short_or_generic"

        if step == 2:
            inside_outside = any(w in a for w in ["داخل", "خارج", "بیرون", "تو", "بیرون"])
            front_obj = any(w in a for w in ["جلوی", "جلو", "روبرو", "مقابل"])
            if not (inside_outside and front_obj):
                return False, "place_needs_inside_outside_and_front_object"

        if step == 5:
            has_hear = any(w in a for w in ["می‌شنوم", "میشنوم", "صدا", "می‌شنوی", "بوی"])
            has_see = any(w in a for w in ["می‌بینم", "می بینم", "تصویر", "می‌بینی", "نور", "رنگ"])
            if not (has_hear or has_see):
                return False, "sensory_needs_hear_or_see"

        if step == 6:
            emo = any(w in a for w in ["آرام", "تنش", "مضطرب", "هیجان", "پرانرژی", "پر انرژی", "مطمئن"])
            body = any(w in a for w in ["نفس", "ضربان", "قلب", "دست", "عرق", "شانه", "گرم", "سرد", "تپش"])
            if not (emo and body):
                return False, "emotion_body_needs_emotion_and_body_signal"

        if step == 7:
            has_identity = any(w in a for w in ["من کسی هستم که", "من فردی هستم که", "من آدمی هستم که"])
            has_behavior = any(w in a for w in ["تماس چشمی", "سؤال می‌پرسم", "سوال میپرسم", "یادداشت", "تمرین", "بدون مکث", "واضح", "درخواست تکرار"])
            if not (has_identity and has_behavior):
                return False, "identity_needs_identity_phrase_and_behavior"

        return True, "ok"

    # ----------------------------
    # Canned phrasing (fallback)
    # ----------------------------
    def _canned_question(self, step: int, fields: Dict[str, Any]) -> str:
        if step == 1:
            return "بیایید یک صحنه ۶ تا ۱۲ ماه جلوتر بسازیم. چه تاریخ مشخصی را تصور می‌کنی؟ (می‌تونه خیالی هم باشه)"
        if step == 2:
            d = fields.get("future_date")
            prefix = f"حالا که گفتی {d}، " if d else ""
            return prefix + "دقیقاً کجا هستی؟ داخل یا خارج؟ چه چیزی جلوی تو/روبروی تو است؟"
        if step == 3:
            return "در همان لحظه، دقیقاً چه کاری را به انگلیسی انجام می‌دهی؟ (مثلاً ارائه، مکالمه، ایمیل، مصاحبه...)"
        if step == 4:
            return "چه کسی/چه کسانی آنجا هستند یا مخاطب تو هستند؟"
        if step == 5:
            return "همان لحظه را زنده‌تر کن: چه چیزی می‌بینی یا چه صدایی می‌شنوی؟ فقط یک جزئیات کافی است."
        if step == 6:
            return "حس و بدن: آن لحظه آرامی یا هیجان‌زده؟ یک نشانه بدنی هم بگو (مثل نفس، ضربان، شانه‌ها...)."
        if step == 7:
            return "این را کامل کن: «من کسی هستم که ...» و بعد یک رفتار واقعی اضافه کن (مثلاً تماس چشمی/یادداشت/سؤال پرسیدن...)."
        return "ممنون. ادامه بدیم."

    def _followup_canned(self, step: int) -> str:
        if step == 2:
            return "یه کم ملموس‌ترش کن: داخل یا خارج؟ و دقیقاً چه چیزی روبروی تو هست؟"
        if step == 5:
            return "فقط یک چیز مشخص بگو: چی می‌بینی یا چه صدایی می‌شنوی؟"
        if step == 7:
            return "خوبه—حالا یک رفتار واقعی اضافه کن که نشان بده واقعاً همون آدمی هستی (مثلاً تماس چشمی/سؤال پرسیدن/یادداشت)."
        return "می‌تونی کمی مشخص‌تر بگی؟ یک جزئیات واقعی اضافه کن."

    def _examples_two(self, step: int) -> str:
        if step == 1:
            return "اگر مطمئن نیستی، یکی را انتخاب کن: «اواخر خرداد سال آینده» یا «۱۰ ماه دیگه، یک روز جمعه» — کدام را ترجیح می‌دهی؟"
        if step == 2:
            return "دو گزینه کوتاه: «داخل کتابخانه، روبروی من لپ‌تاپ و یک لیوان چای» یا «بیرونِ یک کافه، روبروی من دفترچه و گوشی» — کدام نزدیک‌تره؟"
        if step == 3:
            return "دو گزینه: «دارم یک ارائه ۳ دقیقه‌ای به انگلیسی می‌دم» یا «دارم با یک نفر انگلیسی صحبت می‌کنم و سؤال می‌پرسم» — کدام را انتخاب می‌کنی؟"
        if step == 4:
            return "دو گزینه: «استاد و چند همکلاسی» یا «یک مصاحبه‌گر/همکار خارجی» — کدام نزدیک‌تره؟"
        if step == 5:
            return "دو گزینه: «صدای تایپ و کولر» یا «صدای آدم‌ها و موسیقی آرام» — کدام را می‌شنوی/می‌بینی؟"
        if step == 6:
            return "دو گزینه: «آرامم و نفس‌هام عمیقه» یا «کمی هیجان دارم و ضربانم بالاتر رفته» — کدام نزدیک‌تره؟"
        if step == 7:
            return "دو گزینه: «من کسی هستم که ارتباط چشمی حفظ می‌کنه و واضح حرف می‌زنه» یا «من کسی هستم که وقتی گیر می‌کنه سؤال می‌پرسه و یادداشت برمی‌داره» — کدام را انتخاب می‌کنی؟"
        return "یکی از دو گزینه را انتخاب کن یا چیزی شبیهش بگو."

    # ----------------------------
    # Main API
    # ----------------------------
    def process_message(self, message: Optional[str], client_version: str = "", reset: bool = False) -> Dict[str, Any]:
        state = self._reset_state() if reset else self._get_or_create_state()

        try:
            fields = json.loads(state.fields_json or "{}")
        except Exception:
            fields = {}
        retries = fields.get("_retries", {})

        step = int(state.current_step)

        # If reset call / initial ping with empty message: ask first question
        if not message or message.strip() == "":
            q = self._ask_question(step, fields)
            return self._to_dict(ChatResult(bot=q, step=step, needs_user=True, can_start_session=False))

        user_msg = message.strip()

        # Step 8 confirm/edit
        if step == 8:
            if any(w in user_msg for w in EDIT_WORDS):
                self._reset_state()
                q = self._ask_question(1, {})
                return self._to_dict(ChatResult(bot=q, step=1, needs_user=True, can_start_session=False))
            if any(w in user_msg for w in CONFIRM_WORDS):
                final = "اپیزود قفل شد ✅\n۱۰ ثانیه تصورش کن… وقتی آماده‌ای دکمه شروع رو بزن."
                # persist confirmation
                fields["_confirmed"] = True
                state.fields_json = json.dumps(fields, ensure_ascii=False)
                state.last_updated = datetime.utcnow()
                self.db.flush()
                return self._to_dict(ChatResult(
                    bot=final,
                    step=8,
                    needs_user=False,
                    can_start_session=True,
                    episode_summary=fields.get("_summary"),
                    debug=self._debug_payload(True, "confirmed") if DEV_MODE else None
                ))
            # otherwise steer
            bot = "برای ادامه فقط یکی را بفرست: «تایید» یا «ویرایش»."
            return self._to_dict(ChatResult(
                bot=bot, step=8, needs_user=True, can_start_session=False,
                episode_summary=fields.get("_summary"),
                debug=self._debug_payload(False, "awaiting_confirm") if DEV_MODE else None
            ))

        # "not sure" handling
        if any(w in user_msg for w in NOT_SURE_WORDS):
            bot = self._examples_two(step)
            return self._to_dict(ChatResult(
                bot=bot, step=step, needs_user=True, can_start_session=False,
                debug=self._debug_payload(False, "not_sure") if DEV_MODE else None
            ))

        ok, reason = self._validate_step(step, user_msg)
        if not ok:
            cnt = int(retries.get(str(step), 0))
            cnt += 1
            retries[str(step)] = cnt
            fields["_retries"] = retries

            if cnt <= 1:
                # one follow-up max
                bot = self._followup(step, fields)
                state.fields_json = json.dumps(fields, ensure_ascii=False)
                state.last_updated = datetime.utcnow()
                self.db.flush()
                return self._to_dict(ChatResult(
                    bot=bot,
                    step=step,
                    needs_user=True,
                    can_start_session=False,
                    debug=self._debug_payload(False, reason) if DEV_MODE else None
                ))

            # second fail → examples
            retries[str(step)] = 0
            fields["_retries"] = retries
            state.fields_json = json.dumps(fields, ensure_ascii=False)
            state.last_updated = datetime.utcnow()
            self.db.flush()
            bot = self._examples_two(step)
            return self._to_dict(ChatResult(
                bot=bot,
                step=step,
                needs_user=True,
                can_start_session=False,
                debug=self._debug_payload(False, "examples_after_fail") if DEV_MODE else None
            ))

        # Save answer
        fields[STEP_KEYS[step]] = user_msg
        # reset retry counter
        retries[str(step)] = 0
        fields["_retries"] = retries

        # advance step
        state.current_step = step + 1
        state.fields_json = json.dumps(fields, ensure_ascii=False)
        state.last_updated = datetime.utcnow()
        self.db.flush()

        # Step 8 → generate summary
        if state.current_step == 8:
            summary = self._summarize(fields)
            fields["_summary"] = summary
            state.fields_json = json.dumps(fields, ensure_ascii=False)
            state.last_updated = datetime.utcnow()
            self.db.flush()

            bot = f"{summary}\n\nاگر درسته «تایید» بفرست. اگر می‌خوای از نو بسازی «ویرایش»."
            return self._to_dict(ChatResult(
                bot=bot,
                step=8,
                needs_user=True,
                can_start_session=False,
                episode_summary=summary,
                debug=self._debug_payload(True, "summary_ready") if DEV_MODE else None
            ))

        # Otherwise ask next question
        q = self._ask_question(state.current_step, fields)
        return self._to_dict(ChatResult(
            bot=q,
            step=state.current_step,
            needs_user=True,
            can_start_session=False,
            debug=self._debug_payload(True, "step_advanced") if DEV_MODE else None
        ))

    # ----------------------------
    # Wording generators
    # ----------------------------
    def _ask_question(self, step: int, fields: Dict[str, Any]) -> str:
        if step not in STEP_KEYS:
            # step 8 handled elsewhere
            return "ممنون. یک لحظه…"
        # Use LLM for natural phrasing (optional)
        context = self._context_line(fields, step)
        prompt = (
            f"{context}\n"
            f"مرحله {step}: {self._step_goal_text(step)}\n"
            "یک سوال کوتاه و طبیعی بپرس که دقیقاً همین مرحله را جمع کند و از کاربر بخواهد مشخص و ملموس جواب دهد."
        )
        msg = self._llm(self._system_prompt(), prompt)
        return msg or self._canned_question(step, fields)

    def _followup(self, step: int, fields: Dict[str, Any]) -> str:
        context = self._context_line(fields, step)
        prompt = (
            f"{context}\n"
            f"پاسخ کاربر برای مرحله {step} خیلی کلی/کوتاه بود. "
            "فقط یک پیام کوتاه بده که او را به جزئیات واقعی برگرداند. یک سوال بپرس."
        )
        msg = self._llm(self._system_prompt(), prompt, max_tokens=110)
        return msg or self._followup_canned(step)

    def _summarize(self, fields: Dict[str, Any]) -> str:
        # deterministic short summary; optionally LLM polish
        base = (
            "خلاصه اپیزود:\n"
            f"تاریخ: {fields.get('future_date','')}\n"
            f"مکان: {fields.get('place','')}\n"
            f"کار انگلیسی: {fields.get('action','')}\n"
            f"مخاطب: {fields.get('people','')}\n"
            f"حس/صدا/تصویر: {fields.get('sensory','')}\n"
            f"احساس+بدن: {fields.get('emotion_body','')}\n"
            f"هویت+رفتار: {fields.get('identity','')}"
        )
        prompt = (
            "این اطلاعات را در یک پاراگراف کوتاه و روان فارسی خلاصه کن. "
            "خیلی کوتاه، بدون شماره‌گذاری، طبیعی و قابل تصور. "
            "اطلاعات:\n" + base
        )
        msg = self._llm(self._system_prompt(), prompt, max_tokens=170)
        return msg or base

    def _context_line(self, fields: Dict[str, Any], step: int) -> str:
        parts = []
        for s in range(1, step):
            k = STEP_KEYS.get(s)
            if k and fields.get(k):
                parts.append(f"{k}: {fields[k]}")
        if not parts:
            return "اطلاعات قبلی: (هیچ)"
        return "اطلاعات قبلی:\n" + "\n".join(parts)

    def _step_goal_text(self, step: int) -> str:
        return {
            1: "تاریخ مشخص ۶–۱۲ ماه آینده",
            2: "مکان دقیق + داخل/خارج + یک چیز روبرو",
            3: "کار مشخصی که الان به انگلیسی انجام می‌دهد",
            4: "افراد/مخاطب",
            5: "یک جزئیات دیداری یا شنیداری",
            6: "احساس + یک نشانه بدنی",
            7: "هویت + یک رفتار ملموس",
        }.get(step, "")

    def _debug_payload(self, passed: bool, reason: str) -> Dict[str, Any]:
        return {"validation_passed": passed, "reason": reason}

    def _to_dict(self, r: ChatResult) -> Dict[str, Any]:
        d = {
            "bot": r.bot,
            "step": r.step,
            "needs_user": r.needs_user,
            "can_start_session": r.can_start_session,
            "episode_summary": r.episode_summary,
        }
        if DEV_MODE:
            d["debug"] = r.debug or {}
        return d
