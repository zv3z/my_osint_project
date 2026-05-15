"""Threat scoring engine — aggregates engine results into a single risk score"""

WEIGHTS = {
    "VirusTotal":        {"malicious": 4, "suspicious": 2},
    "AlienVault OTX":    {"pulse_count": 0.5},
    "AbuseIPDB":         {"abuseConfidenceScore": 0.8},
    "ThreatFox":         {"total": 3},
    "URLhaus":           {"urls_count": 2},
    "GreyNoise":         {"noise": 10},
    "CriminalIP":        {"is_vpn": 5, "is_tor": 20, "is_proxy": 5, "is_scanner": 10},
    "IPQS":              {"fraud_score": 0.6, "tor": 20, "proxy": 10, "vpn": 8},
    "HaveIBeenPwned":    {"count": 5},
    "LeakCheck":         {"found": 15},
    "MalwareBazaar":     {"file_name": 30},
    "HybridAnalysis":    {"count": 2},
    # New engines
    "PhishTank":         {"in_database": 40, "verified": 20},
    "Google SafeBrowsing":{"safe": -5},
    "ThreatMiner":       {"pdns_records": 0.3},
    "EmailRep":          {"suspicious": 15, "malicious_activity": 25,
                          "credentials_leaked": 20, "data_breach": 15},
    "StopForumSpam":     {"appears": 12},
    "SpamHaus":          {"zone_count": 15},
    "Dehashed":          {"total": 0.2},
    # New engines
    "Ahmia (Dark Web)":  {"found": 25},
    "Shodan InternetDB": {"vulns": 15},
}

RISK_LABELS = {
    (0, 20):   ("LOW",      "#00ff9d", "✅"),
    (20, 45):  ("MEDIUM",   "#ffaa00", "⚠️"),
    (45, 70):  ("HIGH",     "#ff6b35", "🔴"),
    (70, 101): ("CRITICAL", "#ff0000", "☠️"),
}

def compute_score(results: dict) -> dict:
    score = 0.0
    contributions = {}

    for engine, data in results.items():
        if not isinstance(data, dict) or "error" in data:
            continue
        pts = 0.0
        w = WEIGHTS.get(engine, {})
        for field, weight in w.items():
            val = data.get(field)
            if val is None:
                continue
            if isinstance(val, bool):
                pts += weight if val else 0
            elif isinstance(val, (int, float)):
                pts += min(val * weight, weight * 50)
            elif isinstance(val, str) and val not in ("N/A", "", "none"):
                pts += weight

        # Special list-based scoring rules
        if engine == "Shodan InternetDB":
            vulns = data.get("vulns", [])
            if isinstance(vulns, list):
                pts += min(len(vulns), 3) * 15  # 15 pts per vuln, capped at 3

        if pts > 0:
            contributions[engine] = round(pts, 1)
        score += pts

    clamped = min(100, round(score))

    label, color, icon = "LOW", "#00ff9d", "✅"
    for (lo, hi), (lbl, col, icn) in RISK_LABELS.items():
        if lo <= clamped < hi:
            label, color, icon = lbl, col, icn
            break

    return {
        "score": clamped,
        "label": label,
        "color": color,
        "icon": icon,
        "contributions": dict(sorted(contributions.items(), key=lambda x: -x[1])[:8]),
    }
