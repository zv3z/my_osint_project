"""Identity, breach, and OSINT engines"""
import requests
from titan.config import CONF

def _whois(target, ttype):
    try:
        key = CONF["WHOIS_KEY"]
        if not key: return {"status": "no_key"}
        r = requests.get("https://www.whoisxmlapi.com/whoisserver/WhoisService",
                         params={"apiKey": key, "domainName": target, "outputFormat": "JSON"},
                         timeout=12)
        wr = r.json().get("WhoisRecord", {})
        return {"registrar": wr.get("registrarName","N/A"),
                "createdDate": wr.get("createdDate","N/A"),
                "expiresDate": wr.get("expiresDate","N/A"),
                "updatedDate": wr.get("updatedDate","N/A"),
                "registrantOrg": wr.get("registrant",{}).get("organization","N/A"),
                "nameServers": wr.get("nameServers",{}).get("hostNames",[])[:4],
                "status": wr.get("status","N/A")}
    except Exception as e:
        return {"error": str(e)}

def _leakcheck(target, ttype):
    try:
        key = CONF['LEAKCHECK_KEY']
        if not key: return {"status": "no_key"}
        r = requests.get(f"https://leakcheck.io/api?key={key}&type=email&check={target}", timeout=12)
        return r.json()
    except Exception as e:
        return {"error": str(e)}

def _breach(target, ttype):
    try:
        key = CONF["BREACH_KEY"]
        if not key: return {"status": "no_key"}
        r = requests.get(f"https://breachdirectory.p.rapidapi.com/?func=auto&term={target}",
                         headers={"X-RapidAPI-Key": key,
                                  "X-RapidAPI-Host": "breachdirectory.p.rapidapi.com"}, timeout=12)
        return r.json()
    except Exception as e:
        return {"error": str(e)}

def _intelx(target, ttype):
    try:
        key = CONF["INTELX_KEY"]
        if not key: return {"status": "no_key"}
        r = requests.get(f"https://2.intelx.io/intelligent/search",
                         params={"k": key, "q": target, "limit": 5}, timeout=12)
        return r.json()
    except Exception as e:
        return {"error": str(e)}

def _hunter(target, ttype):
    try:
        key = CONF["HUNTER_KEY"]
        if not key: return {"status": "no_key"}
        domain = target if ttype == "DOMAIN" else target.split("@")[-1] if ttype == "EMAIL" else target
        r = requests.get(f"https://api.hunter.io/v2/domain-search",
                         params={"domain": domain, "api_key": key}, timeout=12)
        d = r.json().get("data", {})
        return {"total_emails": len(d.get("emails",[])), "organization": d.get("organization","N/A"),
                "pattern": d.get("pattern","N/A"),
                "emails_preview": [e.get("value") for e in d.get("emails",[])[:5]]}
    except Exception as e:
        return {"error": str(e)}

def _haveibeenpwned(target, ttype):
    try:
        if ttype != "EMAIL":
            return {"status": "email_only"}
        r = requests.get(f"https://haveibeenpwned.com/api/v3/breachedaccount/{target}",
                         headers={"hibp-api-key": "free", "User-Agent": "TitanOSINT"}, timeout=12)
        if r.status_code == 404:
            return {"breached": False, "count": 0}
        if r.status_code == 200:
            breaches = r.json()
            return {"breached": True, "count": len(breaches),
                    "names": [b.get("Name") for b in breaches[:10]]}
        return {"status": f"http_{r.status_code}"}
    except Exception as e:
        return {"error": str(e)}

IDENTITY_ENGINES = {
    "WhoisXML":          _whois,
    "LeakCheck":         _leakcheck,
    "BreachDirectory":   _breach,
    "IntelX":            _intelx,
    "Hunter.io":         _hunter,
    "HaveIBeenPwned":    _haveibeenpwned,
}
