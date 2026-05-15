"""Configuration — loads API keys from Streamlit secrets (Cloud) or .env (local)."""
import os
from dotenv import load_dotenv

load_dotenv()

def _e(*names: str) -> str:
    """Try Streamlit secrets first, then env vars."""
    # Streamlit secrets (Cloud deployment)
    try:
        import streamlit as st
        for n in names:
            v = st.secrets.get(n, "")
            if v and str(v).strip():
                return str(v).strip()
    except Exception:
        pass
    # Local .env fallback
    for n in names:
        v = os.getenv(n, "").strip()
        if v:
            return v
    return ""

CONF: dict[str, str] = {
    # AI
    "GEMINI_KEY":      _e("GEMINI_KEY"),
    "OPENAI_KEY":      _e("OPENAI_KEY"),
    # Threat Intel
    "VT_KEY":          _e("VIRUSTOTAL_KEY", "VT_KEY"),
    "ALIEN_KEY":       _e("ALIENVAULT_KEY", "ALIEN_KEY"),
    "HYBRID_KEY":      _e("HYBRID_ANALYSIS_KEY", "HYBRID_KEY"),
    "KASPER_KEY":      _e("KASPER_KEY"),
    "PULSEDIVE_KEY":   _e("PULSEDIVE_KEY"),
    "MALTIVERSE_KEY":  _e("MALTIVERSE_KEY"),
    # Network / Recon
    "SHODAN_KEY":      _e("SHODAN_KEY"),
    "CENSYS_KEY":      _e("CENSYS_KEY"),
    "ZOOMEYE_KEY":     _e("ZOOMEYE_KEY"),
    "CRIMINALIP_KEY":  _e("CRIMINALIP_KEY"),
    "GREYNOISE_KEY":   _e("GREYNOISE_KEY"),
    "SECTRAILS_KEY":   _e("SECURITYTRAILS_KEY", "SECTRAILS_KEY"),
    # Reputation
    "ABUSE_KEY":       _e("ABUSEIPDB_KEY", "ABUSE_KEY"),
    "IPQS_KEY":        _e("IPQS_KEY"),
    "URLSCAN_KEY":     _e("URLSCAN_KEY"),
    # Identity / Breach
    "HIBP_KEY":        _e("HIBP_KEY"),
    "DEHASHED_EMAIL":  _e("DEHASHED_EMAIL"),
    "LEAKCHECK_KEY":   _e("LEAKCHECK_KEY"),
    "BREACH_KEY":      _e("BREACHDIRECTORY_KEY", "BREACH_KEY"),
    "INTELX_KEY":      _e("INTELX_KEY"),
    "HUNTER_KEY":      _e("HUNTER_KEY"),
    "WIGLE_KEY":       _e("WIGLE_KEY"),
    "WIGLE_NAME":      _e("WIGLE_NAME"),
    # DNS / WHOIS
    "WHOIS_KEY":       _e("WHOISXML_KEY", "WHOIS_KEY"),
    "PUBLICWWW_KEY":   _e("PUBLICWWW_KEY"),
    "VULNERS_KEY":     _e("VULNERS_KEY"),
    # Misc
    "IPINFO_KEY":      _e("IPINFO_KEY"),
    # Developer / Code
    "GITHUB_TOKEN":    _e("GITHUB_TOKEN"),
    "GITLAB_TOKEN":    _e("GITLAB_TOKEN"),
    "SNYK_TOKEN":      _e("SNYK_TOKEN"),
    "BUILTWITH_KEY":   _e("BUILTWITH_KEY"),
    # New Threat
    "GSB_KEY":         _e("GOOGLE_SAFE_BROWSING_KEY", "GSB_KEY"),
    "PHISHTANK_KEY":   _e("PHISHTANK_KEY"),
    # New Identity / Breach
    "DEHASHED_KEY":    _e("DEHASHED_KEY"),
    # New Phone
    "NUMVERIFY_KEY":   _e("NUMVERIFY_KEY"),
    "ABSTRACT_KEY":    _e("ABSTRACT_API_KEY", "ABSTRACT_KEY"),
}

# Derived helpers
AI_AVAILABLE   = bool(CONF["GEMINI_KEY"] or CONF["OPENAI_KEY"])
GEO_AVAILABLE  = True
ACTIVE_ENGINES = sum(1 for k, v in CONF.items()
                     if v and k not in ("GEMINI_KEY", "OPENAI_KEY"))
