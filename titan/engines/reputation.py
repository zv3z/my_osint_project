"""Reputation & abuse engines"""
import requests
from titan.config import CONF

def _abuseipdb(target, ttype):
    try:
        key = CONF["ABUSE_KEY"]
        if not key: return {"status": "no_key"}
        r = requests.get("https://api.abuseipdb.com/api/v2/check",
                         params={"ipAddress": target, "maxAgeInDays": 90, "verbose": True},
                         headers={"Key": key, "Accept": "application/json"}, timeout=12)
        d = r.json().get("data", {})
        return {"abuseConfidenceScore": d.get("abuseConfidenceScore",0),
                "totalReports": d.get("totalReports",0),
                "numDistinctUsers": d.get("numDistinctUsers",0),
                "countryCode": d.get("countryCode","N/A"),
                "usageType": d.get("usageType","N/A"),
                "isp": d.get("isp","N/A"), "isWhitelisted": d.get("isWhitelisted",False)}
    except Exception as e:
        return {"error": str(e)}

def _ipqs(target, ttype):
    try:
        key = CONF["IPQS_KEY"]
        if not key:
            return {"status": "no_key"}
        if ttype == "IP":
            r = requests.get(f"https://www.ipqualityscore.com/api/json/ip/{key}/{target}", timeout=10)
        elif ttype == "EMAIL":
            r = requests.get(f"https://www.ipqualityscore.com/api/json/email/{key}/{target}", timeout=10)
        elif ttype == "URL":
            from urllib.parse import quote
            r = requests.get(f"https://www.ipqualityscore.com/api/json/url/{key}/{quote(target,safe='')}", timeout=10)
        else:
            return {"status": "unsupported"}
        d = r.json()
        return {"fraud_score": d.get("fraud_score",0), "proxy": d.get("proxy",False),
                "vpn": d.get("vpn",False), "tor": d.get("tor",False),
                "bot_status": d.get("bot_status",False), "suspicious": d.get("suspicious",False),
                "country_code": d.get("country_code","N/A")}
    except Exception as e:
        return {"error": str(e)}

def _urlscan(target, ttype):
    try:
        key = CONF["URLSCAN_KEY"]
        if not key: return {"status": "no_key"}
        if ttype not in ("URL", "DOMAIN", "IP"):
            return {"status": "unsupported"}
        # Search existing results first (instant); submit new scan only for URLs
        query = f"domain:{target}" if ttype == "DOMAIN" else f"ip:{target}" if ttype == "IP" else f"page.url:{target}"
        r = requests.get("https://urlscan.io/api/v1/search/",
                         params={"q": query, "size": 5},
                         headers={"API-Key": key}, timeout=12)
        d = r.json()
        results = d.get("results", [])
        if results:
            latest = results[0].get("page", {})
            return {"total": d.get("total", 0),
                    "country": latest.get("country", "N/A"),
                    "server": latest.get("server", "N/A"),
                    "ip": latest.get("ip", "N/A"),
                    "screenshot": results[0].get("screenshot", ""),
                    "verdict": results[0].get("verdicts", {}).get("overall", {}).get("score", 0)}
        # If no existing results, submit a scan for URLs
        if ttype == "URL":
            rs = requests.post("https://urlscan.io/api/v1/scan/",
                               json={"url": target, "visibility": "private"},
                               headers={"API-Key": key}, timeout=12)
            return {"submitted": True, "uuid": rs.json().get("uuid", "N/A")}
        return {"total": 0, "message": "No existing scans found"}
    except Exception as e:
        return {"error": str(e)}

def _vulners(target, ttype):
    try:
        key = CONF['VULNERS_KEY']
        if not key: return {"status": "no_key"}
        r = requests.get(f"https://vulners.com/api/v3/search/lucene/?query={target}&apiKey={key}", timeout=12)
        return {"total": r.json().get("data",{}).get("total",0)}
    except Exception as e:
        return {"error": str(e)}

def _publicwww(target, ttype):
    try:
        key = CONF['PUBLICWWW_KEY']
        if not key: return {"status": "no_key"}
        r = requests.get(f"https://publicwww.com/profile/{target}.json?key={key}", timeout=12)
        return r.json()
    except Exception as e:
        return {"error": str(e)}

def _wigle(target, ttype):
    try:
        key = CONF["WIGLE_KEY"]
        name = CONF.get("WIGLE_NAME", "")
        if not key: return {"status": "no_key"}
        import base64
        # Wigle uses Basic Auth with API Name + API Token, or just token as bearer
        if name:
            creds = base64.b64encode(f"{name}:{key}".encode()).decode()
            headers = {"Authorization": f"Basic {creds}"}
        else:
            headers = {"Authorization": f"Basic {key}"}
        r = requests.get("https://api.wigle.net/api/v2/network/search",
                         params={"ssid": target} if ttype == "UNKNOWN" else {"netid": target},
                         headers=headers, timeout=12)
        d = r.json()
        return {"totalResults": d.get("totalResults", 0), "success": d.get("success", False),
                "results": len(d.get("results", []))}
    except Exception as e:
        return {"error": str(e)}

def _emailrep(target, ttype):
    try:
        if ttype != "EMAIL":
            return {"status": "email_only"}
        r = requests.get(f"https://emailrep.io/{target}",
                         headers={"User-Agent": "TitanOSINT/3.0"}, timeout=10)
        if r.status_code != 200:
            return {"status": f"http_{r.status_code}"}
        d = r.json()
        return {"reputation": d.get("reputation", "N/A"),
                "suspicious": d.get("suspicious", False),
                "spam": d.get("details", {}).get("spam", False),
                "malicious_activity": d.get("details", {}).get("malicious_activity", False),
                "credentials_leaked": d.get("details", {}).get("credentials_leaked", False),
                "data_breach": d.get("details", {}).get("data_breach", False),
                "days_since_domain_creation": d.get("details", {}).get("days_since_domain_creation", -1),
                "profiles": d.get("details", {}).get("profiles", [])[:5]}
    except Exception as e:
        return {"error": str(e)}

def _stopforumspam(target, ttype):
    try:
        if ttype not in ("IP", "EMAIL"):
            return {"status": "unsupported"}
        param = "ip" if ttype == "IP" else "email"
        r = requests.get("https://api.stopforumspam.org/api",
                         params={param: target, "json": 1}, timeout=10)
        d = r.json()
        field = d.get(param, {})
        return {"appears": field.get("appears", 0) == 1,
                "frequency": field.get("frequency", 0),
                "lastseen": field.get("lastseen", "N/A"),
                "confidence": field.get("confidence", 0)}
    except Exception as e:
        return {"error": str(e)}

def _spamhaus(target, ttype):
    try:
        if ttype != "IP":
            return {"status": "ip_only"}
        import socket, ipaddress
        try:
            ipaddress.ip_address(target)
        except ValueError:
            return {"status": "invalid_ip"}
        reversed_ip = ".".join(target.split(".")[::-1])
        listed, zones = [], ["zen.spamhaus.org", "xbl.spamhaus.org", "sbl.spamhaus.org"]
        for zone in zones:
            try:
                socket.gethostbyname(f"{reversed_ip}.{zone}")
                listed.append(zone.split(".")[0].upper())
            except socket.gaierror:
                pass
        return {"listed": bool(listed), "zones": listed, "zone_count": len(listed)}
    except Exception as e:
        return {"error": str(e)}

REPUTATION_ENGINES = {
    "AbuseIPDB":    _abuseipdb,
    "IPQS":         _ipqs,
    "URLScan":      _urlscan,
    "Vulners":      _vulners,
    "PublicWWW":    _publicwww,
    "Wigle":        _wigle,
    "EmailRep":     _emailrep,
    "StopForumSpam":_stopforumspam,
    "SpamHaus":     _spamhaus,
}
