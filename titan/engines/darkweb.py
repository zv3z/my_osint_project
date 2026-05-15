"""Dark web & paste monitoring engines"""
import requests
from titan.config import CONF

def _ahmia(target, ttype):
    """Search Ahmia.fi — clearnet Tor search index"""
    try:
        if ttype not in ("DOMAIN", "EMAIL", "IP", "UNKNOWN"):
            return {"status": "unsupported"}
        r = requests.get("https://ahmia.fi/search/",
                         params={"q": target},
                         headers={"User-Agent": "TitanOSINT/3.0"},
                         timeout=15)
        if r.status_code != 200:
            return {"status": f"http_{r.status_code}"}
        # Count .onion results in response
        onion_count = r.text.count(".onion")
        result_count = r.text.count('class="result"')
        return {"onion_mentions": onion_count,
                "results": result_count,
                "found": result_count > 0,
                "source": "ahmia.fi"}
    except Exception as e:
        return {"error": str(e)}

def _dehashed_public(target, ttype):
    """DeHashed public search — check breach count without auth"""
    try:
        if ttype not in ("EMAIL", "DOMAIN", "IP"):
            return {"status": "unsupported"}
        r = requests.get("https://dehashed.com/search",
                         params={"query": target},
                         headers={"User-Agent": "Mozilla/5.0 TitanOSINT"},
                         timeout=12)
        count = r.text.count("breach-entry") if r.status_code == 200 else 0
        return {"breach_entries_visible": count, "found": count > 0}
    except Exception as e:
        return {"error": str(e)}

DARKWEB_ENGINES = {
    "Ahmia (Dark Web)":  _ahmia,
    "DeHashed Public":   _dehashed_public,
}
