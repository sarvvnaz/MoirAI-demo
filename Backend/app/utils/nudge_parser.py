# app/utils/nudge_parser.py
import json, re

def extract_nudge_messages(raw: str) -> list[str]:
    """
    Try hard to get a list of message strings out of a JSON-ish model output.
    1) Clean code fences / smart quotes / trailing commas
    2) Attempt json.loads
    3) Fallback: regex over `"message": "..."` pairs
    """
    if not isinstance(raw, str):
        try:
            # if caller accidentally passed a dict, normalize
            return [n.get("message","").strip() for n in raw.get("nudges", []) if n.get("message")]
        except Exception:
            return []

    s = raw.strip()

    # remove ```json ... ``` fences if present
    if s.startswith("```"):
        s = re.sub(r"^```(?:json)?\s*|\s*```$", "", s, flags=re.S)

    # normalize smart quotes
    s = (s.replace("“", '"').replace("”", '"').replace("’", "'"))

    # keep only the biggest {...} block if there is extra prose
    m = re.search(r"\{.*\}", s, re.S)
    if m:
        s = m.group(0)

    # remove trailing commas before ] or }
    s = re.sub(r",(\s*[}\]])", r"\1", s)

    # try strict JSON first
    try:
        data = json.loads(s)
        msgs = [ (n.get("message") or "").strip()
                 for n in (data.get("nudges") or [])
                 if (n.get("message") or "").strip() ]
        if msgs:
            return msgs
    except Exception:
        pass

    # fallback: greedy but robust – grab any "message": "..."
    msgs = re.findall(r'"message"\s*:\s*"([^"]+)"', s, re.S)
    print(msgs)
    return [m.strip() for m in msgs if m.strip()]
