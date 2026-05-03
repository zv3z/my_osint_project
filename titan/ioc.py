"""IOC extractor — pulls indicators of compromise from raw engine results"""
import re, json

_IP_RE     = re.compile(r'\b(?:(?:25[0-5]|2[0-4]\d|[01]?\d\d?)\.){3}(?:25[0-5]|2[0-4]\d|[01]?\d\d?)\b')
_DOMAIN_RE = re.compile(r'\b(?:[a-zA-Z0-9](?:[a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?\.)+[a-zA-Z]{2,}\b')
_EMAIL_RE  = re.compile(r'\b[\w.\-+]+@[\w.\-]+\.[a-zA-Z]{2,}\b')
_MD5_RE    = re.compile(r'\b[a-fA-F0-9]{32}\b')
_SHA1_RE   = re.compile(r'\b[a-fA-F0-9]{40}\b')
_SHA256_RE = re.compile(r'\b[a-fA-F0-9]{64}\b')
_CVE_RE    = re.compile(r'\bCVE-\d{4}-\d{4,7}\b', re.I)
_URL_RE    = re.compile(r'https?://[^\s\'"<>]{5,}')

_PRIVATE_NETS = {
    "10.", "172.16.", "172.17.", "172.18.", "172.19.",
    "172.20.", "172.21.", "172.22.", "172.23.", "172.24.",
    "172.25.", "172.26.", "172.27.", "172.28.", "172.29.",
    "172.30.", "172.31.", "192.168.", "127.", "0.0.0.0",
}

_NOISE_DOMAINS = {"n/a", "example.com", "localhost", "local", "internal"}

def _is_private_ip(ip: str) -> bool:
    return any(ip.startswith(p) for p in _PRIVATE_NETS)

def _flatten(obj, depth=0) -> str:
    if depth > 6:
        return ""
    if isinstance(obj, str):
        return obj
    if isinstance(obj, (int, float, bool)):
        return str(obj)
    if isinstance(obj, (list, tuple)):
        return " ".join(_flatten(x, depth+1) for x in obj)
    if isinstance(obj, dict):
        return " ".join(_flatten(v, depth+1) for v in obj.values())
    return ""


def extract(results: dict, original_target: str = "") -> dict:
    blob = _flatten(results)

    ips      = {ip for ip in _IP_RE.findall(blob) if not _is_private_ip(ip)}
    domains  = {d.lower() for d in _DOMAIN_RE.findall(blob)
                if d.lower() not in _NOISE_DOMAINS and len(d) > 4}
    emails   = set(_EMAIL_RE.findall(blob))
    sha256   = set(_SHA256_RE.findall(blob))
    sha1     = {h for h in _SHA1_RE.findall(blob) if h not in sha256}
    md5      = {h for h in _MD5_RE.findall(blob) if h not in sha256 and h not in sha1}
    cves     = {c.upper() for c in _CVE_RE.findall(blob)}
    urls     = set(_URL_RE.findall(blob))

    # Remove the scanned target itself from results to avoid noise
    t = original_target.lower()
    ips.discard(original_target)
    domains.discard(t)
    emails.discard(t)

    iocs = []
    for ip in sorted(ips)[:30]:
        iocs.append({"type": "IP",     "value": ip})
    for d in sorted(domains)[:30]:
        iocs.append({"type": "DOMAIN", "value": d})
    for e in sorted(emails)[:20]:
        iocs.append({"type": "EMAIL",  "value": e})
    for h in sorted(sha256)[:10]:
        iocs.append({"type": "SHA256", "value": h})
    for h in sorted(sha1)[:10]:
        iocs.append({"type": "SHA1",   "value": h})
    for h in sorted(md5)[:10]:
        iocs.append({"type": "MD5",    "value": h})
    for c in sorted(cves)[:20]:
        iocs.append({"type": "CVE",    "value": c})
    for u in sorted(urls)[:15]:
        iocs.append({"type": "URL",    "value": u})

    return {
        "iocs": iocs,
        "summary": {
            "ips": len(ips), "domains": len(domains), "emails": len(emails),
            "hashes": len(sha256) + len(sha1) + len(md5),
            "cves": len(cves), "urls": len(urls),
            "total": len(iocs),
        }
    }


def to_csv(ioc_data: dict) -> str:
    lines = ["type,value"]
    for item in ioc_data.get("iocs", []):
        lines.append(f'{item["type"]},{item["value"]}')
    return "\n".join(lines)
