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
        key = CONF.get("HIBP_KEY", "")
        if not key:
            return {"status": "no_key"}
        r = requests.get(f"https://haveibeenpwned.com/api/v3/breachedaccount/{target}",
                         headers={"hibp-api-key": key, "User-Agent": "TitanOSINT"}, timeout=12)
        if r.status_code == 404:
            return {"breached": False, "count": 0}
        if r.status_code == 200:
            breaches = r.json()
            return {"breached": True, "count": len(breaches),
                    "names": [b.get("Name") for b in breaches[:10]]}
        return {"status": f"http_{r.status_code}"}
    except Exception as e:
        return {"error": str(e)}

def _username_search(target, ttype):
    try:
        if ttype not in ("GITHUB", "UNKNOWN"):
            return {"status": "unsupported"}
        username = target.lstrip("@").split("/")[-1]
        h = {"User-Agent": "Mozilla/5.0 TitanOSINT"}
        checks = {
            "GitHub":    (f"https://api.github.com/users/{username}", 200),
            "GitLab":    (f"https://gitlab.com/api/v4/users?username={username}", 200),
            "Reddit":    (f"https://www.reddit.com/user/{username}/about.json", 200),
            "HackerNews":(f"https://hacker-news.firebaseio.com/v0/user/{username}.json", 200),
            "Keybase":   (f"https://keybase.io/_/api/1.0/user/lookup.json?username={username}", 200),
            "Dev.to":    (f"https://dev.to/api/users/by_username?url={username}", 200),
        }
        found, not_found = [], []
        for platform, (url, ok_code) in checks.items():
            try:
                r = requests.get(url, headers=h, timeout=7)
                if r.status_code == ok_code:
                    d = r.json() if r.text.strip().startswith("{") or r.text.strip().startswith("[") else {}
                    if platform == "GitLab" and (not isinstance(d, list) or len(d) == 0):
                        not_found.append(platform)
                    elif platform == "HackerNews" and not d:
                        not_found.append(platform)
                    elif platform == "Keybase" and d.get("status", {}).get("code", -1) != 0:
                        not_found.append(platform)
                    else:
                        found.append(platform)
                else:
                    not_found.append(platform)
            except Exception:
                pass
        return {"username": username, "found_on": found,
                "not_found_on": not_found, "found_count": len(found),
                "checked_platforms": len(checks)}
    except Exception as e:
        return {"error": str(e)}

def _dehashed(target, ttype):
    try:
        key = CONF.get("DEHASHED_KEY", "")
        if not key:
            return {"status": "no_key"}
        if ttype not in ("EMAIL", "DOMAIN", "IP"):
            return {"status": "unsupported"}
        field = "email" if ttype == "EMAIL" else "ip_address" if ttype == "IP" else "email"
        email = CONF.get("DEHASHED_EMAIL", "")
        if not email:
            return {"status": "no_key"}
        r = requests.get("https://api.dehashed.com/search",
                         params={"query": f'{field}:"{target}"', "size": 10},
                         auth=(email, key), timeout=12)
        d = r.json()
        entries = d.get("entries", []) or []
        return {"total": d.get("total", 0),
                "found": len(entries),
                "sources": list({e.get("database_name","") for e in entries if e.get("database_name")})[:8],
                "has_passwords": any(e.get("password") for e in entries)}
    except Exception as e:
        return {"error": str(e)}

def _gravatar(target, ttype):
    try:
        if ttype != "EMAIL":
            return {"status": "email_only"}
        import hashlib
        email_hash = hashlib.md5(target.strip().lower().encode()).hexdigest()
        r = requests.get(f"https://www.gravatar.com/{email_hash}.json",
                         headers={"User-Agent": "TitanOSINT/3.0"}, timeout=10)
        if r.status_code == 200:
            entry = r.json().get("entry", [{}])[0]
            return {"has_gravatar": True,
                    "display_name": entry.get("displayName", "N/A"),
                    "profile_url": entry.get("profileUrl", "N/A"),
                    "verified_accounts": len(entry.get("accounts", [])),
                    "linked_accounts": [a.get("shortname") for a in entry.get("accounts", [])[:8]],
                    "location": entry.get("currentLocation", "N/A")}
        return {"has_gravatar": False}
    except Exception as e:
        return {"error": str(e)}

IDENTITY_ENGINES = {
    "WhoisXML":          _whois,
    "LeakCheck":         _leakcheck,
    "BreachDirectory":   _breach,
    "IntelX":            _intelx,
    "Hunter.io":         _hunter,
    "HaveIBeenPwned":    _haveibeenpwned,
    "Username Search":   _username_search,
    "Dehashed":          _dehashed,
    "Gravatar":          _gravatar,
}
