"""Titan OSINT — FastAPI backend for mobile app"""
import sys, os
sys.path.insert(0, os.path.dirname(__file__))

import json, datetime, logging, secrets
import httpx
from fastapi import FastAPI, HTTPException, Request, Query, Path, Depends, Security
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from fastapi.security import APIKeyHeader
from pydantic import BaseModel, field_validator

from titan.classifier import classify
from titan.engines    import run_all
from titan.scoring    import compute_score
from titan.ioc        import extract as extract_iocs
from titan.ai_engine  import analyze as ai_analyze, chat as ai_chat
from titan.db         import (save_scan, get_history, get_cached, set_cache,
                               add_bookmark, add_note, get_notes, stats,
                               get_target_history, get_watched_targets,
                               create_share, get_share)
from titan.config     import CONF, AI_AVAILABLE, ACTIVE_ENGINES

logger = logging.getLogger("titan_api")

# ── Auth ──────────────────────────────────────────────────────────
# Set TITAN_API_KEY env var to enforce key-based auth.
# If unset, the API runs unauthenticated (local/dev mode).
_TITAN_KEY = os.environ.get("TITAN_API_KEY", "")
_api_key_header = APIKeyHeader(name="X-API-Key", auto_error=False)

async def verify_key(key: str | None = Security(_api_key_header)):
    if _TITAN_KEY and key != _TITAN_KEY:
        raise HTTPException(status_code=403, detail="Invalid or missing API key")

# Allowed origins — set CORS_ORIGINS env var (comma-separated) for production
_raw_origins = os.environ.get("CORS_ORIGINS", "")
ALLOWED_ORIGINS = [o.strip() for o in _raw_origins.split(",") if o.strip()] or ["*"]

app = FastAPI(title="Titan OSINT API", version="3.2.0")

app.add_middleware(
    CORSMiddleware,
    allow_origins=ALLOWED_ORIGINS,
    allow_methods=["GET", "POST"],
    allow_headers=["Content-Type", "Authorization", "X-API-Key"],
)

@app.exception_handler(Exception)
async def global_exception_handler(request: Request, exc: Exception):
    logger.exception("Unhandled error on %s", request.url)
    return JSONResponse(status_code=500, content={"detail": "Internal server error"})

# ── Models ────────────────────────────────────────────────────────
class ScanRequest(BaseModel):
    target: str
    use_cache: bool = True
    lang: str = "ar"

    @field_validator("target")
    @classmethod
    def target_not_empty(cls, v: str) -> str:
        v = v.strip()
        if not v:
            raise ValueError("target must not be empty")
        if len(v) > 512:
            raise ValueError("target too long (max 512 chars)")
        return v

    @field_validator("lang")
    @classmethod
    def lang_valid(cls, v: str) -> str:
        if v not in ("ar", "en"):
            return "en"
        return v

class ChatRequest(BaseModel):
    message: str
    target: str
    ttype: str
    results: dict
    ai_analysis: str
    lang: str = "ar"

    @field_validator("message")
    @classmethod
    def message_not_empty(cls, v: str) -> str:
        if not v.strip():
            raise ValueError("message must not be empty")
        if len(v) > 4096:
            raise ValueError("message too long (max 4096 chars)")
        return v

class NoteRequest(BaseModel):
    target: str
    body: str

    @field_validator("body")
    @classmethod
    def body_not_empty(cls, v: str) -> str:
        if not v.strip():
            raise ValueError("note body must not be empty")
        return v

class BookmarkRequest(BaseModel):
    target: str
    ttype: str

class ShareRequest(BaseModel):
    target: str

# ── Routes ────────────────────────────────────────────────────────

@app.get("/")
def root():
    return {"name": "Titan OSINT API", "version": "3.2.0", "status": "online",
            "active_engines": ACTIVE_ENGINES, "ai_available": AI_AVAILABLE}

@app.post("/scan", dependencies=[Depends(verify_key)])
def scan(req: ScanRequest):
    target = req.target  # already validated + stripped by Pydantic

    ttype      = classify(target)
    results    = None
    from_cache = False

    if req.use_cache:
        cached = get_cached(target)
        if cached:
            try:
                results = json.loads(cached[2])
                from_cache = bool(results)
            except (json.JSONDecodeError, TypeError):
                logger.warning("Corrupt cache entry for %s, re-scanning", target)

    if not from_cache:
        results = run_all(target, ttype)
        if results:
            try:
                payload = json.dumps(results)
                set_cache(target, payload)
                save_scan(target, ttype, payload)
            except (TypeError, ValueError) as exc:
                logger.error("Could not serialise scan results: %s", exc)

    if not results:
        raise HTTPException(500, "Scan produced no results")

    score    = compute_score(results)
    ioc_data = extract_iocs(results, target)

    return {
        "target":      target,
        "ttype":       ttype,
        "from_cache":  from_cache,
        "scan_ts":     datetime.datetime.now().isoformat(),
        "score":       score,
        "ioc_data":    ioc_data,
        "results":     results,
    }

@app.post("/analyze", dependencies=[Depends(verify_key)])
def analyze(req: ScanRequest):
    target = req.target  # already validated + stripped by Pydantic
    cached = get_cached(target)
    if not cached:
        raise HTTPException(404, "Run a scan first")

    try:
        results = json.loads(cached[2])
    except (json.JSONDecodeError, TypeError):
        raise HTTPException(500, "Cached scan data is corrupt — please re-scan")

    ttype    = classify(target)
    analysis = ai_analyze(target, ttype, results, req.lang)
    return {"analysis": analysis}

@app.post("/chat", dependencies=[Depends(verify_key)])
def chat(req: ChatRequest):
    ctx = {
        "target":      req.target,
        "ttype":       req.ttype,
        "results":     req.results,
        "ai_analysis": req.ai_analysis,
    }
    reply = ai_chat(req.message, ctx, req.lang)
    return {"reply": reply}

@app.get("/history", dependencies=[Depends(verify_key)])
def history(limit: int = 50):
    limit = max(1, min(limit, 500))  # clamp: 1–500
    rows = get_history(limit=limit)
    return [
        {"id": r[0], "ts": r[1], "target": r[2], "ttype": r[3],
         "score": r[4], "label": r[5], "summary": r[6]}
        for r in rows
    ]

@app.get("/stats", dependencies=[Depends(verify_key)])
def get_stats():
    return stats()

@app.post("/bookmark", dependencies=[Depends(verify_key)])
def bookmark(req: BookmarkRequest):
    add_bookmark(req.target, req.ttype)
    return {"ok": True}

@app.get("/notes/{target}", dependencies=[Depends(verify_key)])
def get_target_notes(
    target: str = Path(..., max_length=512, description="Target to fetch notes for"),
):
    notes = get_notes(target)
    return [{"id": n[0], "target": n[1], "body": n[2], "ts": n[3]} for n in notes]

@app.post("/notes", dependencies=[Depends(verify_key)])
def save_note(req: NoteRequest):
    add_note(req.target, req.body)
    return {"ok": True}

@app.get("/config", dependencies=[Depends(verify_key)])
def get_config():
    # Only expose boolean flags — never expose key material
    return {
        "active_engines": ACTIVE_ENGINES,
        "ai_available":   AI_AVAILABLE,
        "has_gemini":     bool(CONF.get("GEMINI_KEY")),
        "has_openai":     bool(CONF.get("OPENAI_KEY")),
    }

@app.get("/timeline/{target}", dependencies=[Depends(verify_key)])
def timeline(
    target: str = Path(..., max_length=512, description="Target to fetch score history for"),
):
    rows = get_target_history(target)
    return [{"id": r[0], "ts": r[1], "score": r[2], "level": r[3]} for r in rows]


@app.get("/watched", dependencies=[Depends(verify_key)])
def watched():
    return get_watched_targets()

@app.post("/share", dependencies=[Depends(verify_key)])
def create_share_endpoint(req: ShareRequest):
    """Create a public shareable link for a scan result"""
    cached = get_cached(req.target)
    if not cached:
        raise HTTPException(404, "No scan found for this target — run a scan first")
    token = secrets.token_urlsafe(16)
    try:
        results = json.loads(cached[2])
        score = compute_score(results)
        payload = json.dumps({"target": req.target, "ttype": classify(req.target),
                              "results": results, "score": score})
        create_share(req.target, token, payload)
    except Exception as e:
        raise HTTPException(500, f"Share creation failed: {e}")
    return {"token": token, "url": f"/public/{token}"}

@app.get("/cve/recent")
def recent_cves(limit: int = 20, severity: str = ""):
    """Fetch recent CVEs from NVD — no auth required for public dashboard"""
    params = {"resultsPerPage": min(limit, 50), "startIndex": 0}
    if severity.upper() in ("CRITICAL","HIGH","MEDIUM","LOW"):
        params["cvssV3Severity"] = severity.upper()
    try:
        r = httpx.get("https://services.nvd.nist.gov/rest/json/cves/2.0",
                      params=params, timeout=15,
                      headers={"User-Agent": "TitanOSINT/3.2"})
        data = r.json()
        cves = []
        for item in data.get("vulnerabilities", []):
            cve = item.get("cve", {})
            metrics = cve.get("metrics", {})
            cvss = (metrics.get("cvssMetricV31") or metrics.get("cvssMetricV30") or
                    metrics.get("cvssMetricV2") or [{}])
            score = cvss[0].get("cvssData", {}).get("baseScore", 0) if cvss else 0
            severity_val = cvss[0].get("cvssData", {}).get("baseSeverity", "N/A") if cvss else "N/A"
            descs = cve.get("descriptions", [])
            desc = next((d["value"] for d in descs if d["lang"] == "en"), "N/A")
            cves.append({
                "id": cve.get("id"),
                "published": cve.get("published", "")[:10],
                "score": score,
                "severity": severity_val,
                "description": desc[:200],
                "references": len(cve.get("references", [])),
            })
        return {"total": data.get("totalResults", 0), "cves": cves}
    except Exception as e:
        return {"error": str(e), "cves": []}

@app.get("/dashboard/stats")
def dashboard_stats():
    """Aggregate stats for dashboard — no auth"""
    db_stats = stats()
    return {
        "scans_total": db_stats.get("total_scans", 0),
        "targets_unique": db_stats.get("unique_targets", 0),
        "high_risk": db_stats.get("high_risk", 0),
        "engines_active": ACTIVE_ENGINES,
        "engines_total": 56,
        "ai_available": AI_AVAILABLE,
    }

@app.get("/dashboard/noise")
def global_noise():
    """GreyNoise top attacking countries — uses key if available"""
    key = CONF.get("GREYNOISE_KEY", "")
    if not key:
        return {"status": "no_key", "message": "Add GREYNOISE_KEY for live data"}
    try:
        r = httpx.get("https://api.greynoise.io/v2/experimental/gnql/stats",
                      params={"query": "classification:malicious", "count": 10},
                      headers={"key": key}, timeout=12)
        return r.json()
    except Exception as e:
        return {"error": str(e)}

@app.get("/public/{token}")
def get_public_share(token: str = Path(..., max_length=32)):
    """Public endpoint — no auth required — for shared scan reports"""
    row = get_share(token)
    if not row:
        raise HTTPException(404, "Share not found or expired")
    try:
        return json.loads(row[3])
    except Exception:
        raise HTTPException(500, "Corrupted share data")
