"""Reputation & abuse engines"""
import requests
from titan.config import CONF

def _abuseipdb(target, ttype):
    try:
        r = requests.get("https://api.abuseipdb.com/api/v2/check",
                         params={"ipAddress": target, "maxAgeInDays": 90, "verbose": True},
                         headers={"Key": CONF["ABUSE_KEY"], "Accept": "application/json"}, timeout=12)
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
        r = requests.post("https://urlscan.io/api/v1/scan/",
                          json={"url": target, "visibility": "private"},
                          headers={"API-Key": CONF["URLSCAN_KEY"]}, timeout=12)
        return r.json()
    except Exception as e:
        return {"error": str(e)}

def _vulners(target, ttype):
    try:
        r = requests.get(f"https://vulners.com/api/v3/search/lucene/?query={target}&apiKey={CONF['VULNERS_KEY']}", timeout=12)
        return {"total": r.json().get("data",{}).get("total",0)}
    except Exception as e:
        return {"error": str(e)}

def _publicwww(target, ttype):
    try:
        r = requests.get(f"https://publicwww.com/profile/{target}.json?key={CONF['PUBLICWWW_KEY']}", timeout=12)
        return r.json()
    except Exception as e:
        return {"error": str(e)}

def _wigle(target, ttype):
    try:
        from requests.auth import HTTPBasicAuth
        r = requests.get(f"https://api.wigle.net/api/v2/network/search?netid={target}",
                         auth=HTTPBasicAuth(CONF["WIGLE_KEY"],""), timeout=12)
        d = r.json()
        return {"totalResults": d.get("totalResults",0), "success": d.get("success",False)}
    except Exception as e:
        return {"error": str(e)}

REPUTATION_ENGINES = {
    "AbuseIPDB": _abuseipdb,
    "IPQS":      _ipqs,
    "URLScan":   _urlscan,
    "Vulners":   _vulners,
    "PublicWWW": _publicwww,
    "Wigle":     _wigle,
}
