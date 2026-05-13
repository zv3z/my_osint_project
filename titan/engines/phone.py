"""Phone Intelligence engines"""
import re, requests
from titan.config import CONF

_CC_MAP = {
    "+1": "USA/Canada", "+7": "Russia/Kazakhstan", "+20": "Egypt",
    "+27": "South Africa", "+30": "Greece", "+31": "Netherlands",
    "+32": "Belgium", "+33": "France", "+34": "Spain", "+36": "Hungary",
    "+39": "Italy", "+40": "Romania", "+41": "Switzerland",
    "+44": "United Kingdom", "+45": "Denmark", "+46": "Sweden",
    "+47": "Norway", "+48": "Poland", "+49": "Germany",
    "+51": "Peru", "+52": "Mexico", "+54": "Argentina", "+55": "Brazil",
    "+56": "Chile", "+57": "Colombia", "+58": "Venezuela",
    "+60": "Malaysia", "+61": "Australia", "+62": "Indonesia",
    "+63": "Philippines", "+64": "New Zealand", "+65": "Singapore",
    "+66": "Thailand", "+81": "Japan", "+82": "South Korea",
    "+84": "Vietnam", "+86": "China", "+90": "Turkey", "+91": "India",
    "+92": "Pakistan", "+93": "Afghanistan", "+94": "Sri Lanka",
    "+98": "Iran", "+212": "Morocco", "+213": "Algeria",
    "+216": "Tunisia", "+218": "Libya", "+220": "Gambia",
    "+221": "Senegal", "+234": "Nigeria", "+249": "Sudan",
    "+251": "Ethiopia", "+254": "Kenya", "+255": "Tanzania",
    "+256": "Uganda", "+260": "Zambia", "+263": "Zimbabwe",
    "+351": "Portugal", "+352": "Luxembourg", "+353": "Ireland",
    "+354": "Iceland", "+355": "Albania", "+358": "Finland",
    "+359": "Bulgaria", "+380": "Ukraine", "+381": "Serbia",
    "+385": "Croatia", "+386": "Slovenia", "+420": "Czech Republic",
    "+421": "Slovakia", "+966": "Saudi Arabia", "+967": "Yemen",
    "+968": "Oman", "+970": "Palestine", "+971": "UAE",
    "+972": "Israel", "+973": "Bahrain", "+974": "Qatar",
    "+975": "Bhutan", "+976": "Mongolia", "+977": "Nepal",
    "+992": "Tajikistan", "+993": "Turkmenistan", "+994": "Azerbaijan",
    "+995": "Georgia", "+996": "Kyrgyzstan", "+998": "Uzbekistan",
}


def _phone_basic(target, ttype):
    """Free phone intelligence — country detection, format validation, E.164 check."""
    try:
        if ttype != "PHONE":
            return {"status": "phone_only"}
        cleaned = re.sub(r"[\s\-\(\)\[\]\.\/]", "", target)
        digits = re.sub(r"\D", "", cleaned)
        country = "Unknown"
        for cc, name in sorted(_CC_MAP.items(), key=lambda x: -len(x[0])):
            if cleaned.startswith(cc):
                country = name
                break
        e164 = cleaned if cleaned.startswith("+") else f"+{digits}"
        return {
            "cleaned": cleaned,
            "e164_format": e164,
            "digits": digits,
            "digit_length": len(digits),
            "country_guess": country,
            "has_country_code": cleaned.startswith("+"),
            "looks_valid": 7 <= len(digits) <= 15,
            "is_e164": bool(re.match(r"^\+[1-9]\d{6,14}$", e164)),
        }
    except Exception as e:
        return {"error": str(e)}


def _numverify(target, ttype):
    try:
        if ttype != "PHONE":
            return {"status": "phone_only"}
        key = CONF.get("NUMVERIFY_KEY", "")
        if not key:
            return {"status": "no_key"}
        phone = re.sub(r"[^\d+]", "", target)
        r = requests.get("http://apilayer.net/api/validate",
                         params={"access_key": key, "number": phone, "format": 1},
                         timeout=10)
        d = r.json()
        return {"valid": d.get("valid", False),
                "international": d.get("international_format", "N/A"),
                "local": d.get("local_format", "N/A"),
                "country_name": d.get("country_name", "N/A"),
                "country_code": d.get("country_code", "N/A"),
                "carrier": d.get("carrier", "N/A"),
                "line_type": d.get("line_type", "N/A")}
    except Exception as e:
        return {"error": str(e)}


def _abstract_phone(target, ttype):
    try:
        if ttype != "PHONE":
            return {"status": "phone_only"}
        key = CONF.get("ABSTRACT_KEY", "")
        if not key:
            return {"status": "no_key"}
        phone = re.sub(r"[^\d+]", "", target)
        r = requests.get("https://phonevalidation.abstractapi.com/v1/",
                         params={"api_key": key, "phone": phone}, timeout=10)
        d = r.json()
        return {"valid": d.get("valid", False),
                "phone": d.get("phone", "N/A"),
                "international_format": d.get("format", {}).get("international", "N/A"),
                "country": d.get("country", {}).get("name", "N/A"),
                "country_code": d.get("country", {}).get("phone_code", "N/A"),
                "carrier": d.get("carrier", "N/A"),
                "type": d.get("type", "N/A")}
    except Exception as e:
        return {"error": str(e)}


def _stopforumspam_phone(target, ttype):
    """Check if phone appears in StopForumSpam database."""
    try:
        if ttype != "PHONE":
            return {"status": "phone_only"}
        phone = re.sub(r"[^\d+]", "", target)
        r = requests.get("https://api.stopforumspam.org/api",
                         params={"phone": phone, "json": 1}, timeout=10)
        d = r.json().get("phone", {})
        return {"appears": d.get("appears", 0) == 1,
                "frequency": d.get("frequency", 0),
                "lastseen": d.get("lastseen", "N/A")}
    except Exception as e:
        return {"error": str(e)}


PHONE_ENGINES = {
    "PhoneBasic":      _phone_basic,
    "NumVerify":       _numverify,
    "AbstractAPI":     _abstract_phone,
    "PhoneSpamCheck":  _stopforumspam_phone,
}
