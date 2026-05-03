"""TitanAI — Gemini-powered cyber analyst with automatic model fallback.

Model priority (new SDK):  gemini-2.5-flash-lite → gemini-2.5-flash → gemini-2.0-flash
Old SDK fallback:          gemini-1.5-flash
Final fallback:            OpenAI gpt-4o-mini
"""
import json, re, warnings
from titan.config import CONF

# ── SDK init ───────────────────────────────────────────────────────────────
_SDK    = None   # "new" | "old" | None
_client = None

# Ordered by quota availability — lite first, then more capable
_MODELS_NEW = [
    "gemini-2.5-flash-lite",
    "gemini-flash-lite-latest",
    "gemini-flash-latest",
    "gemini-2.0-flash",
]
_MODEL_OLD = "gemini-1.5-flash"


def _init_gemini():
    global _SDK, _client
    if _SDK is not None or not CONF["GEMINI_KEY"]:
        return
    try:
        from google import genai as _g
        _client = _g.Client(api_key=CONF["GEMINI_KEY"])
        _SDK = "new"
        return
    except Exception:
        pass
    try:
        with warnings.catch_warnings():
            warnings.simplefilter("ignore")
            import google.generativeai as _gold
        _gold.configure(api_key=CONF["GEMINI_KEY"])
        _client = _gold.GenerativeModel(_MODEL_OLD)
        _SDK = "old"
    except Exception:
        _SDK = None


SYSTEM_PROMPT = (
    "You are TitanAI, an elite cybersecurity analyst embedded inside the Titan OSINT Platform.\n"
    "You have access to data from 33+ intelligence engines: VirusTotal, Shodan, AbuseIPDB, "
    "AlienVault OTX, GreyNoise, CriminalIP, Censys, ThreatFox, URLhaus, MalwareBazaar, "
    "Hunter.io, HaveIBeenPwned, IntelX, Pulsedive, Kaspersky TIP, BGPView, SecurityTrails, "
    "Robtex, crt.sh, Wayback Machine, GitHub, npm, PyPI, and more.\n\n"
    "Your role:\n"
    "1. Synthesize ALL engine results into a cohesive threat assessment\n"
    "2. Identify attack patterns, TTPs, and MITRE ATT&CK techniques\n"
    "3. Assign threat actors or campaign names if recognizable\n"
    "4. Provide actionable defense recommendations\n"
    "5. Flag false positives if data is contradictory\n\n"
    "Response format — structured markdown:\n"
    "## 🎯 Threat Assessment\n"
    "## 🔍 Key Findings\n"
    "## ⚔️ MITRE ATT&CK Techniques\n"
    "## 🛡️ Defense Recommendations\n"
    "## 📊 Confidence Level\n\n"
    "Be precise, technical, and concise. Never hallucinate data."
)


def _call_gemini(prompt: str) -> str | None:
    """Try each model in priority order. Returns text, 'QUOTA', or None."""
    _init_gemini()
    if _SDK is None or _client is None:
        return None

    if _SDK == "new":
        from google.genai import types as t
        for model in _MODELS_NEW:
            try:
                resp = _client.models.generate_content(
                    model=model,
                    contents=prompt,
                    config=t.GenerateContentConfig(
                        system_instruction=SYSTEM_PROMPT,
                        max_output_tokens=2048,
                        temperature=0.3,
                    ),
                )
                return resp.text
            except Exception:
                continue   # try next model regardless of error type
        return "QUOTA"         # all models exhausted

    else:  # old SDK
        try:
            with warnings.catch_warnings():
                warnings.simplefilter("ignore")
                resp = _client.generate_content(SYSTEM_PROMPT + "\n\n" + prompt)
            return resp.text
        except Exception as e:
            err = str(e)
            if "429" in err or "quota" in err.lower():
                return "QUOTA"
            raise


def _no_key_msg(lang: str) -> str:
    if lang == "ar":
        return "⚠️ لا يوجد مفتاح AI مفعّل. أضف `GEMINI_KEY` في ملف .env"
    return "⚠️ No AI key configured. Add `GEMINI_KEY` to your .env file."


def _quota_msg(lang: str) -> str:
    if lang == "ar":
        return (
            "⚠️ **تجاوزت الحصة اليومية المجانية لـ Gemini.**\n\n"
            "الحلول:\n"
            "- انتظر حتى إعادة تعيين الحصة (منتصف الليل بتوقيت UTC)\n"
            "- أضف بيانات بطاقة في Google AI Studio لرفع الحد\n"
            "- أو أضف `OPENAI_KEY` في ملف .env كبديل"
        )
    return (
        "⚠️ **Daily Gemini free quota exceeded.**\n\n"
        "Options:\n"
        "- Wait for quota reset (midnight UTC)\n"
        "- Add billing in Google AI Studio to increase limits\n"
        "- Or add `OPENAI_KEY` in .env as fallback"
    )


def analyze(target: str, ttype: str, results: dict, lang: str = "ar") -> str:
    lang_line = "Respond in Arabic (العربية)." if lang == "ar" else "Respond in English."
    cleaned   = {k: v for k, v in results.items() if isinstance(v, dict) and "error" not in v}

    prompt = (
        f"{lang_line}\n\n"
        f"TARGET: {target}\nTYPE: {ttype}\n\n"
        f"INTELLIGENCE DATA ({len(cleaned)} engines returned data):\n"
        f"{json.dumps(cleaned, ensure_ascii=False, indent=2)[:12000]}\n\n"
        "Provide a complete cyber threat analysis."
    )

    try:
        result = _call_gemini(prompt)
        if result == "QUOTA":
            if CONF["OPENAI_KEY"]:
                return _openai_fallback(prompt, lang)
            return _quota_msg(lang)
        if result is not None:
            return result
    except Exception as e:
        return f"⚠️ Gemini Error: {e}"

    if CONF["OPENAI_KEY"]:
        return _openai_fallback(prompt, lang)
    return _no_key_msg(lang)


def chat(question: str, context: dict, lang: str = "ar") -> str:
    lang_line    = "Respond in Arabic." if lang == "ar" else "Respond in English."
    target       = context.get("target", "unknown")
    ttype        = context.get("ttype",  "UNKNOWN")
    scan_results = context.get("results", {})
    ai_analysis  = context.get("ai_analysis", "")

    cleaned = {k: v for k, v in scan_results.items() if isinstance(v, dict) and "error" not in v}
    prompt = (
        f"{lang_line}\n\n"
        f"TARGET: {target} ({ttype})\n\n"
        f"PRIOR ANALYSIS:\n{ai_analysis[:3000] or 'Not yet performed.'}\n\n"
        f"ENGINE DATA:\n{json.dumps(cleaned, ensure_ascii=False, indent=2)[:6000]}\n\n"
        f"USER QUESTION: {question}\n\nAnswer concisely and technically."
    )

    try:
        result = _call_gemini(prompt)
        if result == "QUOTA":
            if CONF["OPENAI_KEY"]:
                return _openai_fallback(prompt, lang)
            return _quota_msg(lang)
        if result is not None:
            return result
    except Exception as e:
        return f"⚠️ Gemini Error: {e}"

    if CONF["OPENAI_KEY"]:
        return _openai_fallback(prompt, lang)
    return _no_key_msg(lang)


def _openai_fallback(prompt: str, lang: str) -> str:
    try:
        import openai
        client = openai.OpenAI(api_key=CONF["OPENAI_KEY"])
        resp = client.chat.completions.create(
            model="gpt-4o-mini",
            messages=[
                {"role": "system", "content": SYSTEM_PROMPT},
                {"role": "user",   "content": prompt},
            ],
            max_tokens=1500,
        )
        return resp.choices[0].message.content
    except Exception as e:
        err = str(e)
        if "429" in err or "quota" in err.lower():
            return _quota_msg(lang)
        return f"⚠️ OpenAI Error: {err}"


def extract_mitre(analysis_text: str) -> list[dict]:
    found  = re.findall(r'\b(T\d{4}(?:\.\d{3})?)\b', analysis_text)
    unique = list(dict.fromkeys(found))
    return [
        {"id": tid, "url": f"https://attack.mitre.org/techniques/{tid.replace('.','/')}"}
        for tid in unique[:15]
    ]
