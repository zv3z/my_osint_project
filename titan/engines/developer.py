"""Developer / Code Intelligence engines"""
import requests
from titan.config import CONF

def _github(target, ttype):
    try:
        token = CONF["GITHUB_TOKEN"]
        h = {"Authorization": f"token {token}", "Accept": "application/vnd.github+json"} if token else {"Accept": "application/vnd.github+json"}
        if ttype == "GITHUB":
            username = target.lstrip("@")
            u = requests.get(f"https://api.github.com/users/{username}", headers=h, timeout=12).json()
            repos = requests.get(f"https://api.github.com/users/{username}/repos?per_page=5&sort=updated", headers=h, timeout=12).json()
            return {
                "login": u.get("login","N/A"), "name": u.get("name","N/A"),
                "public_repos": u.get("public_repos",0), "followers": u.get("followers",0),
                "created_at": u.get("created_at","N/A"), "bio": u.get("bio","N/A"),
                "company": u.get("company","N/A"), "location": u.get("location","N/A"),
                "top_repos": [{"name": r.get("name"), "stars": r.get("stargazers_count",0),
                               "language": r.get("language")} for r in (repos if isinstance(repos,list) else [])[:5]]
            }
        elif ttype == "DOMAIN":
            r = requests.get(f"https://api.github.com/search/repositories?q={target}&per_page=5", headers=h, timeout=12).json()
            items = r.get("items",[])
            return {"total_count": r.get("total_count",0),
                    "repos": [{"full_name": x.get("full_name"), "stars": x.get("stargazers_count",0)} for x in items[:5]]}
        return {"status": "unsupported"}
    except Exception as e:
        return {"error": str(e)}

def _crtsh(target, ttype):
    try:
        if ttype not in ("DOMAIN","EMAIL"):
            return {"status": "unsupported"}
        r = requests.get(f"https://crt.sh/?q={target}&output=json", timeout=15)
        certs = r.json() if r.status_code == 200 else []
        domains = list({c.get("name_value","").replace("\n","").strip()
                        for c in certs if c.get("name_value")})[:20]
        return {"total_certs": len(certs), "unique_domains": len(domains),
                "sample_domains": domains[:10],
                "issuers": list({c.get("issuer_name","") for c in certs[:30] if c.get("issuer_name")})[:5]}
    except Exception as e:
        return {"error": str(e)}

def _wayback(target, ttype):
    try:
        r = requests.get(f"https://archive.org/wayback/available?url={target}", timeout=12)
        d = r.json()
        snap = d.get("archived_snapshots",{}).get("closest",{})
        cdx = requests.get(f"https://web.archive.org/cdx/search/cdx?url={target}&output=json&limit=5&fl=timestamp,original,statuscode", timeout=15)
        snapshots = cdx.json()[1:] if cdx.status_code == 200 else []
        return {
            "available": snap.get("available", False),
            "closest_snapshot": snap.get("url","N/A"),
            "timestamp": snap.get("timestamp","N/A"),
            "recent_snapshots": [{"ts": s[0], "url": s[1], "status": s[2]} for s in snapshots[:5]]
        }
    except Exception as e:
        return {"error": str(e)}

def _npm(target, ttype):
    try:
        pkg = target.lstrip("@").split("/")[-1] if "@" in target else target
        r = requests.get(f"https://registry.npmjs.org/{pkg}", timeout=12)
        if r.status_code != 200:
            return {"error": f"Package not found: {pkg}"}
        d = r.json()
        latest = d.get("dist-tags",{}).get("latest","")
        vinfo = d.get("versions",{}).get(latest,{})
        deps = list(vinfo.get("dependencies",{}).keys())[:10]
        return {
            "name": d.get("name","N/A"), "description": d.get("description","N/A"),
            "latest": latest, "author": vinfo.get("author",{}).get("name","N/A"),
            "license": vinfo.get("license","N/A"), "dependencies_count": len(deps),
            "dependencies_sample": deps, "homepage": d.get("homepage","N/A"),
            "versions_count": len(d.get("versions",{}))
        }
    except Exception as e:
        return {"error": str(e)}

def _pypi(target, ttype):
    try:
        r = requests.get(f"https://pypi.org/pypi/{target}/json", timeout=12)
        if r.status_code != 200:
            return {"error": f"Package not found: {target}"}
        d = r.json()
        info = d.get("info",{})
        return {
            "name": info.get("name","N/A"), "version": info.get("version","N/A"),
            "summary": info.get("summary","N/A"), "author": info.get("author","N/A"),
            "license": info.get("license","N/A"), "home_page": info.get("home_page","N/A"),
            "requires_python": info.get("requires_python","N/A"),
            "classifiers_count": len(info.get("classifiers",[])),
            "releases_count": len(d.get("releases",{}))
        }
    except Exception as e:
        return {"error": str(e)}

def _builtwith(target, ttype):
    try:
        key = CONF.get("BUILTWITH_KEY", "")
        if not key:
            return {"status": "no_key"}
        if ttype not in ("DOMAIN", "URL"):
            return {"status": "unsupported"}
        domain = target if ttype == "DOMAIN" else target.split("//")[-1].split("/")[0]
        r = requests.get(f"https://api.builtwith.com/v21/api.json",
                         params={"KEY": key, "LOOKUP": domain}, timeout=15)
        d = r.json()
        results = d.get("Results", [{}])[0].get("Result", {}) if d.get("Results") else {}
        paths = results.get("Paths", [{}])[0] if results.get("Paths") else {}
        techs = paths.get("Technologies", [])
        cats = {}
        for t in techs[:30]:
            cat = t.get("Tag", "Other")
            cats.setdefault(cat, []).append(t.get("Name",""))
        return {"technology_count": len(techs),
                "categories": {k: v[:5] for k, v in list(cats.items())[:10]}}
    except Exception as e:
        return {"error": str(e)}

def _subdomains(target, ttype):
    try:
        if ttype != "DOMAIN":
            return {"status": "domain_only"}
        subs = set()
        # Source 1: HackerTarget
        r1 = requests.get(f"https://api.hackertarget.com/hostsearch/?q={target}", timeout=12)
        for line in r1.text.strip().splitlines():
            if "," in line:
                sub = line.split(",")[0].strip()
                if sub.endswith(f".{target}") or sub == target:
                    subs.add(sub)
        # Source 2: crt.sh (reuse existing data)
        r2 = requests.get(f"https://crt.sh/?q=%.{target}&output=json", timeout=15)
        if r2.status_code == 200:
            for cert in r2.json():
                for name in cert.get("name_value", "").split("\n"):
                    name = name.strip().lstrip("*.")
                    if name.endswith(target) and name != target:
                        subs.add(name)
        sorted_subs = sorted(subs)[:40]
        return {"subdomain_count": len(sorted_subs),
                "subdomains": sorted_subs[:20],
                "sources": ["HackerTarget", "CertSH"]}
    except Exception as e:
        return {"error": str(e)}

DEV_ENGINES = {
    "GitHub":     _github,
    "CertSH":     _crtsh,
    "Wayback":    _wayback,
    "NPM":        _npm,
    "PyPI":       _pypi,
    "BuiltWith":  _builtwith,
    "Subdomains": _subdomains,
}
