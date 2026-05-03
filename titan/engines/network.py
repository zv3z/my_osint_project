"""Network Reconnaissance engines"""
import requests, re
from titan.config import CONF

def _shodan(target, ttype):
    try:
        key = CONF['SHODAN_KEY']
        if not key: return {"status": "no_key"}
        r = requests.get(f"https://api.shodan.io/shodan/host/{target}?key={key}", timeout=12)
        d = r.json()
        return {"ports": d.get("ports",[]), "org": d.get("org","N/A"),
                "country": d.get("country_name","N/A"), "city": d.get("city","N/A"),
                "isp": d.get("isp","N/A"), "hostnames": d.get("hostnames",[]),
                "vulns": list(d.get("vulns",{}).keys())[:8], "os": d.get("os","N/A"),
                "tags": d.get("tags",[]), "lat": d.get("latitude"), "lon": d.get("longitude")}
    except Exception as e:
        return {"error": str(e)}

def _censys(target, ttype):
    try:
        key = CONF["CENSYS_KEY"]
        if not key:
            return {"status": "no_key"}
        auth = (key, "")
        r = requests.get(f"https://search.censys.io/api/v2/hosts/{target}", auth=auth, timeout=12)
        d = r.json().get("result", {})
        return {"services": [s.get("service_name") for s in d.get("services",[])],
                "labels": d.get("labels",[]),
                "asn": d.get("autonomous_system",{}).get("name","N/A"),
                "country": d.get("location",{}).get("country","N/A")}
    except Exception as e:
        return {"error": str(e)}

def _zoomeye(target, ttype):
    try:
        key = CONF["ZOOMEYE_KEY"]
        if not key: return {"status": "no_key"}
        r = requests.get(f"https://api.zoomeye.org/host/search?q={target}",
                         headers={"JWT": key}, timeout=12)
        d = r.json()
        return {"total": d.get("total",0), "matches": len(d.get("matches",[]))}
    except Exception as e:
        return {"error": str(e)}

def _criminalip(target, ttype):
    try:
        key = CONF["CRIMINALIP_KEY"]
        if not key: return {"status": "no_key"}
        r = requests.get(f"https://api.criminalip.io/v1/asset/ip/report?ip={target}",
                         headers={"x-api-key": key}, timeout=12)
        d = r.json()
        return {"inbound": d.get("score",{}).get("inbound","N/A"),
                "outbound": d.get("score",{}).get("outbound","N/A"),
                "is_vpn": d.get("is_vpn",False), "is_tor": d.get("is_tor",False),
                "is_proxy": d.get("is_proxy",False), "is_scanner": d.get("is_scanner",False)}
    except Exception as e:
        return {"error": str(e)}

def _greynoise(target, ttype):
    try:
        key = CONF["GREYNOISE_KEY"]
        if not key: return {"status": "no_key"}
        r = requests.get(f"https://api.greynoise.io/v3/community/{target}",
                         headers={"key": key}, timeout=12)
        d = r.json()
        return {"noise": d.get("noise",False), "riot": d.get("riot",False),
                "classification": d.get("classification","N/A"), "name": d.get("name","N/A")}
    except Exception as e:
        return {"error": str(e)}

def _bgpview(target, ttype):
    try:
        if ttype == "IP":
            r = requests.get(f"https://api.bgpview.io/ip/{target}", timeout=10)
            pfx = r.json().get("data",{}).get("prefixes",[])
            asn = pfx[0].get("asn",{}) if pfx else {}
            return {"asn": asn.get("asn","N/A"), "asn_name": asn.get("name","N/A"),
                    "prefix": pfx[0].get("prefix","N/A") if pfx else "N/A",
                    "country": pfx[0].get("country_code","N/A") if pfx else "N/A"}
        elif ttype == "ASN":
            num = re.sub(r"[^0-9]","",target)
            r = requests.get(f"https://api.bgpview.io/asn/{num}", timeout=10)
            d = r.json().get("data",{})
            return {"name": d.get("name","N/A"), "description": d.get("description_short","N/A"),
                    "country": d.get("country_code","N/A"), "emails": d.get("email_contacts",[])[:2]}
        return {"status": "unsupported"}
    except Exception as e:
        return {"error": str(e)}

def _ipinfo(target, ttype):
    try:
        token = CONF["IPINFO_KEY"]
        url = f"https://ipinfo.io/{target}/json" + (f"?token={token}" if token else "")
        r = requests.get(url, timeout=10)
        d = r.json()
        loc = d.get("loc","0,0").split(",")
        return {"city": d.get("city","N/A"), "region": d.get("region","N/A"),
                "country": d.get("country","N/A"), "org": d.get("org","N/A"),
                "timezone": d.get("timezone","N/A"), "hostname": d.get("hostname","N/A"),
                "lat": float(loc[0]) if len(loc)==2 else None,
                "lon": float(loc[1]) if len(loc)==2 else None}
    except Exception as e:
        return {"error": str(e)}

def _robtex(target, ttype):
    try:
        url = (f"https://freeapi.robtex.com/ipquery/{target}" if ttype=="IP"
               else f"https://freeapi.robtex.com/pdns/forward/{target}" if ttype=="DOMAIN"
               else None)
        if not url:
            return {"status": "unsupported"}
        r = requests.get(url, timeout=10)
        import json
        recs = []
        for line in r.text.strip().split("\n")[:10]:
            try: recs.append(json.loads(line))
            except Exception: pass
        return {"records": recs, "count": len(recs)}
    except Exception as e:
        return {"error": str(e)}

def _sectrails(target, ttype):
    try:
        key = CONF["SECTRAILS_KEY"]
        if not key:
            return {"status": "no_key"}
        h = {"APIKEY": key}
        if ttype == "DOMAIN":
            r = requests.get(f"https://api.securitytrails.com/v1/domain/{target}", headers=h, timeout=12)
            d = r.json()
            return {"apex": d.get("apex_domain","N/A"), "alexa": d.get("alexa_rank","N/A"),
                    "a_records": [x.get("ip") for x in d.get("current_dns",{}).get("a",{}).get("values",[])[:5]],
                    "mx_records": [x.get("hostname") for x in d.get("current_dns",{}).get("mx",{}).get("values",[])[:3]]}
        elif ttype == "IP":
            r = requests.get(f"https://api.securitytrails.com/v1/ips/nearby/{target}", headers=h, timeout=12)
            return r.json()
        return {"status": "unsupported"}
    except Exception as e:
        return {"error": str(e)}

NETWORK_ENGINES = {
    "Shodan":         _shodan,
    "Censys":         _censys,
    "ZoomEye":        _zoomeye,
    "CriminalIP":     _criminalip,
    "GreyNoise":      _greynoise,
    "BGPView":        _bgpview,
    "IPInfo":         _ipinfo,
    "Robtex":         _robtex,
    "SecurityTrails": _sectrails,
}
