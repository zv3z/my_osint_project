"""Threat Intelligence engines"""
import requests, base64
from titan.config import CONF

def _vt(target, ttype):
    try:
        key = CONF["VT_KEY"]
        if not key: return {"status": "no_key"}
        h = {"x-apikey": key}
        if ttype == "IP":
            r = requests.get(f"https://www.virustotal.com/api/v3/ip_addresses/{target}", headers=h, timeout=12)
        elif ttype == "DOMAIN":
            r = requests.get(f"https://www.virustotal.com/api/v3/domains/{target}", headers=h, timeout=12)
        elif ttype == "URL":
            uid = base64.urlsafe_b64encode(target.encode()).decode().strip("=")
            r = requests.get(f"https://www.virustotal.com/api/v3/urls/{uid}", headers=h, timeout=12)
        elif ttype in ("MD5","SHA1","SHA256"):
            r = requests.get(f"https://www.virustotal.com/api/v3/files/{target}", headers=h, timeout=12)
        else:
            return {"status": "unsupported"}
        d = r.json().get("data", {}).get("attributes", {})
        s = d.get("last_analysis_stats", {})
        return {"malicious": s.get("malicious",0), "suspicious": s.get("suspicious",0),
                "harmless": s.get("harmless",0), "undetected": s.get("undetected",0),
                "reputation": d.get("reputation",0), "tags": d.get("tags",[])[:5]}
    except Exception as e:
        return {"error": str(e)}

def _alienvault(target, ttype):
    try:
        key = CONF["ALIEN_KEY"]
        if not key: return {"status": "no_key"}
        ep = "IPv4" if ttype=="IP" else "domain" if ttype=="DOMAIN" else "hostname"
        r = requests.get(f"https://otx.alienvault.com/api/v1/indicators/{ep}/{target}/general",
                         headers={"X-OTX-API-KEY": key}, timeout=12)
        d = r.json()
        return {"pulse_count": d.get("pulse_info",{}).get("count",0),
                "malware_families": d.get("malware_families",[])[:5],
                "tags": d.get("tags",[])[:8], "reputation": d.get("reputation",0)}
    except Exception as e:
        return {"error": str(e)}

def _threatfox(target, ttype):
    try:
        r = requests.post("https://threatfox-api.abuse.ch/api/v1/",
                          json={"query":"search_ioc","search_term":target}, timeout=12)
        data = r.json().get("data",[]) or []
        return {"total": len(data),
                "threat_types": list({x.get("threat_type") for x in data if x.get("threat_type")})[:5],
                "malware": list({x.get("malware") for x in data if x.get("malware")})[:5],
                "confidence": data[0].get("confidence_level") if data else 0}
    except Exception as e:
        return {"error": str(e)}

def _urlhaus(target, ttype):
    try:
        if ttype == "URL":
            r = requests.post("https://urlhaus-api.abuse.ch/v1/url/", data={"url": target}, timeout=12)
        elif ttype in ("IP","DOMAIN"):
            r = requests.post("https://urlhaus-api.abuse.ch/v1/host/", data={"host": target}, timeout=12)
        elif ttype in ("MD5","SHA256"):
            key = "md5_hash" if ttype=="MD5" else "sha256_hash"
            r = requests.post("https://urlhaus-api.abuse.ch/v1/payload/", data={key: target}, timeout=12)
        else:
            return {"status": "unsupported"}
        d = r.json()
        return {"query_status": d.get("query_status","N/A"),
                "urls_count": len(d.get("urls",[])),
                "tags": (d.get("tags") or [])[:5]}
    except Exception as e:
        return {"error": str(e)}

def _malwarebazaar(target, ttype):
    try:
        if ttype not in ("MD5","SHA1","SHA256"):
            return {"status": "unsupported"}
        r = requests.post("https://mb-api.abuse.ch/api/v1/", data={"query":"get_info","hash":target}, timeout=12)
        items = r.json().get("data",[])
        if items:
            i = items[0]
            return {"file_name": i.get("file_name"), "file_type": i.get("file_type"),
                    "signature": i.get("signature"), "tags": i.get("tags",[])[:8],
                    "first_seen": i.get("first_seen"), "reporter": i.get("reporter")}
        return {"query_status": r.json().get("query_status","not_found")}
    except Exception as e:
        return {"error": str(e)}

def _hybrid(target, ttype):
    try:
        key = CONF["HYBRID_KEY"]
        if not key: return {"status": "no_key"}
        r = requests.get(f"https://www.hybrid-analysis.com/api/v2/search/terms?term={target}",
                         headers={"api-key": key, "User-Agent": "Falcon Sandbox"}, timeout=12)
        d = r.json()
        return {"count": d.get("count",0), "results": len(d.get("result",[]))}
    except Exception as e:
        return {"error": str(e)}

def _pulsedive(target, ttype):
    try:
        key = CONF["PULSEDIVE_KEY"]
        url = f"https://pulsedive.com/api/info.php?indicator={target}&pretty=1" + (f"&key={key}" if key else "")
        r = requests.get(url, timeout=12)
        d = r.json()
        return {"risk": d.get("risk","N/A"), "feeds": len(d.get("feeds",[])),
                "threats": [t.get("name") for t in d.get("threats",[])[:5]],
                "stamp_seen": d.get("stamp_seen","N/A")}
    except Exception as e:
        return {"error": str(e)}

def _kaspersky(target, ttype):
    try:
        key = CONF["KASPER_KEY"]
        if not key: return {"status": "no_key"}
        ep = "ip" if ttype=="IP" else "domain"
        r = requests.get(f"https://opentip.kaspersky.com/api/v1/search/{ep}?{ep}={target}",
                         headers={"x-api-key": key}, timeout=12)
        return r.json()
    except Exception as e:
        return {"error": str(e)}

def _phishtank(target, ttype):
    try:
        if ttype not in ("URL", "DOMAIN"):
            return {"status": "unsupported"}
        key = CONF.get("PHISHTANK_KEY", "")
        url_check = target if ttype == "URL" else f"http://{target}"
        from urllib.parse import quote
        data = {"url": quote(url_check, safe=""), "format": "json"}
        if key:
            data["app_key"] = key
        r = requests.post("https://checkurl.phishtank.com/checkurl/",
                          data=data, headers={"User-Agent": "phishtank/TitanOSINT"},
                          timeout=12)
        d = r.json().get("results", {})
        return {"in_database": d.get("in_database", False),
                "valid": d.get("valid", False),
                "verified": d.get("verified", False),
                "phish_id": d.get("phish_id"),
                "verified_at": d.get("verified_at", "N/A")}
    except Exception as e:
        return {"error": str(e)}

def _gsb(target, ttype):
    try:
        key = CONF.get("GSB_KEY", "")
        if not key:
            return {"status": "no_key"}
        if ttype not in ("URL", "DOMAIN"):
            return {"status": "unsupported"}
        url_check = target if ttype == "URL" else f"http://{target}"
        payload = {"client": {"clientId": "titan-osint", "clientVersion": "1.0"},
                   "threatInfo": {"threatTypes": ["MALWARE","SOCIAL_ENGINEERING","UNWANTED_SOFTWARE","POTENTIALLY_HARMFUL_APPLICATION"],
                                  "platformTypes": ["ANY_PLATFORM"],
                                  "threatEntryTypes": ["URL"],
                                  "threatEntries": [{"url": url_check}]}}
        r = requests.post(f"https://safebrowsing.googleapis.com/v4/threatMatches:find?key={key}",
                          json=payload, timeout=10)
        matches = r.json().get("matches", [])
        return {"safe": len(matches) == 0,
                "threats": [m.get("threatType") for m in matches],
                "platform": [m.get("platformType") for m in matches[:3]]}
    except Exception as e:
        return {"error": str(e)}

def _threatminer(target, ttype):
    try:
        if ttype == "IP":
            ep, param = "host.php", "host"
        elif ttype == "DOMAIN":
            ep, param = "domain.php", "domain"
        elif ttype in ("MD5", "SHA1", "SHA256"):
            ep, param = "sample.php", "hash"
        else:
            return {"status": "unsupported"}
        r = requests.get(f"https://api.threatminer.org/v2/{ep}",
                         params={param: target, "rt": "1"}, timeout=12)
        d = r.json()
        results = d.get("results", [])
        # rt=2 passive DNS
        r2 = requests.get(f"https://api.threatminer.org/v2/{ep}",
                          params={param: target, "rt": "2"}, timeout=12)
        pdns = r2.json().get("results", [])[:8]
        return {"status_code": d.get("status_code", "N/A"),
                "whois_entries": len(results),
                "pdns_records": len(pdns),
                "pdns_sample": [{"ip": p.get("ip",""), "domain": p.get("domain","")}
                                for p in pdns[:5]],
                "whois_preview": results[0] if results else {}}
    except Exception as e:
        return {"error": str(e)}

THREAT_ENGINES = {
    "VirusTotal":    _vt,
    "AlienVault OTX":_alienvault,
    "ThreatFox":     _threatfox,
    "URLhaus":       _urlhaus,
    "MalwareBazaar": _malwarebazaar,
    "HybridAnalysis":_hybrid,
    "Pulsedive":     _pulsedive,
    "Kaspersky TIP": _kaspersky,
    "PhishTank":     _phishtank,
    "Google SafeBrowsing": _gsb,
    "ThreatMiner":   _threatminer,
}
