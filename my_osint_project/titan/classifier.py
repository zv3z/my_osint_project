"""Target type classifier"""
import re, ipaddress

TYPE_COLORS = {
    "IP":      "#00e5b4", "DOMAIN":  "#4ea8ff", "EMAIL":  "#f59f00",
    "MD5":     "#f03e3e", "SHA1":    "#f03e3e", "SHA256": "#f03e3e",
    "URL":     "#ffe066", "ASN":     "#cc99ff", "PHONE":  "#ff99bb",
    "GITHUB":  "#aaaaff", "NPM":     "#cc4444", "UNKNOWN":"#888888",
}

def classify(target: str) -> str:
    t = target.strip()
    try:
        ipaddress.ip_address(t)
        return "IP"
    except ValueError:
        pass
    if re.match(r'^[\w.\-]+@[\w.\-]+\.\w+$', t):           return "EMAIL"
    if re.match(r'^[a-fA-F0-9]{64}$', t):                  return "SHA256"
    if re.match(r'^[a-fA-F0-9]{40}$', t):                  return "SHA1"
    if re.match(r'^[a-fA-F0-9]{32}$', t):                  return "MD5"
    if re.match(r'^https?://', t):                          return "URL"
    if re.match(r'^AS\d+$', t, re.I):                      return "ASN"
    if re.match(r'^\+?[\d\s\-()\[\]]{7,16}$', t):          return "PHONE"
    # GitHub user or org
    if re.match(r'^github\.com/[\w\-]+$', t, re.I):        return "GITHUB"
    if re.match(r'^@?[\w\-]{1,39}$', t) and '.' not in t:  return "GITHUB"
    # npm package
    if re.match(r'^@[\w\-]+/[\w\-]+$', t) or \
       re.match(r'^[a-z][\w.\-]{0,213}$', t) and len(t) < 50 and '.' not in t:
        pass  # fall through to domain check
    if re.match(r'^[a-zA-Z0-9][a-zA-Z0-9\-.]+\.[a-zA-Z]{2,}$', t):
        return "DOMAIN"
    return "UNKNOWN"
