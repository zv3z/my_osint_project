"""Titan OSINT — FastAPI backend for mobile app"""
import sys, os
sys.path.insert(0, os.path.dirname(__file__))

import json, datetime
from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from typing import Optional

from titan.classifier import classify
from titan.engines    import run_all
from titan.scoring    import compute_score
from titan.ioc        import extract as extract_iocs, to_csv as iocs_to_csv
from titan.ai_engine  import analyze as ai_analyze, chat as ai_chat
from titan.db         import (save_scan, get_history, get_cached, set_cache,
                               add_bookmark, add_note, get_notes, stats)
from titan.config     import CONF, AI_AVAILABLE, ACTIVE_ENGINES

app = FastAPI(title="Titan OSINT API", version="3.1.0")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

# ── Models ────────────────────────────────────────────────────────
class ScanRequest(BaseModel):
    target: str
    use_cache: bool = True
    lang: str = "ar"

class ChatRequest(BaseModel):
    message: str
    target: str
    ttype: str
    results: dict
    ai_analysis: str
    lang: str = "ar"

class NoteRequest(BaseModel):
    target: str
    body: str

class BookmarkRequest(BaseModel):
    target: str
    ttype: str

# ── Routes ────────────────────────────────────────────────────────

@app.get("/")
def root():
    return {"name": "Titan OSINT API", "version": "3.1.0", "status": "online",
            "active_engines": ACTIVE_ENGINES, "ai_available": AI_AVAILABLE}

@app.post("/scan")
def scan(req: ScanRequest):
    target = req.target.strip()
    if not target:
        raise HTTPException(400, "Target is required")

    ttype     = classify(target)
    cached    = get_cached(target) if req.use_cache else None
    from_cache = cached is not None

    if cached:
        results = json.loads(cached[2])
    else:
        results = run_all(target, ttype)
        set_cache(target, json.dumps(results))
        save_scan(target, ttype, json.dumps(results))

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

@app.post("/analyze")
def analyze(req: ScanRequest):
    target = req.target.strip()
    cached = get_cached(target)
    if not cached:
        raise HTTPException(404, "Run a scan first")

    results = json.loads(cached[2])
    ttype   = classify(target)
    analysis = ai_analyze(target, ttype, results, req.lang)
    return {"analysis": analysis}

@app.post("/chat")
def chat(req: ChatRequest):
    ctx = {
        "target":      req.target,
        "ttype":       req.ttype,
        "results":     req.results,
        "ai_analysis": req.ai_analysis,
    }
    reply = ai_chat(req.message, ctx, req.lang)
    return {"reply": reply}

@app.get("/history")
def history(limit: int = 50):
    rows = get_history(limit=limit)
    return [
        {"id": r[0], "ts": r[1], "target": r[2], "ttype": r[3],
         "score": r[4], "label": r[5], "summary": r[6]}
        for r in rows
    ]

@app.get("/stats")
def get_stats():
    return stats()

@app.post("/bookmark")
def bookmark(req: BookmarkRequest):
    add_bookmark(req.target, req.ttype)
    return {"ok": True}

@app.get("/notes/{target}")
def get_target_notes(target: str):
    notes = get_notes(target)
    return [{"id": n[0], "target": n[1], "body": n[2], "ts": n[3]} for n in notes]

@app.post("/notes")
def save_note(req: NoteRequest):
    add_note(req.target, req.body)
    return {"ok": True}

@app.get("/config")
def get_config():
    return {"active_engines": ACTIVE_ENGINES, "ai_available": AI_AVAILABLE,
            "has_gemini": bool(CONF.get("GEMINI_KEY")),
            "has_openai": bool(CONF.get("OPENAI_KEY"))}
