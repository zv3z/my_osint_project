"""Database layer — SQLite (titan.db)
Column layout matches app.py expectations exactly:
  get_history  → (id, ts, target, ttype, score, level, summary)
  get_cached   → (hash, ts, data_json)  or None
  get_bookmarks→ (id, target, ttype, ts)
  get_notes    → (id, target, body, ts)
"""
import sqlite3, hashlib, html
from datetime import datetime, timedelta
from pathlib import Path

DB_PATH = Path(__file__).parent.parent / "titan.db"


def _conn():
    c = sqlite3.connect(DB_PATH)
    c.row_factory = sqlite3.Row
    return c


def init():
    with sqlite3.connect(DB_PATH) as c:
        c.executescript("""
        CREATE TABLE IF NOT EXISTS scans (
            id          INTEGER PRIMARY KEY AUTOINCREMENT,
            ts          DATETIME DEFAULT CURRENT_TIMESTAMP,
            target      TEXT NOT NULL,
            ttype       TEXT,
            score       INTEGER DEFAULT 0,
            level       TEXT    DEFAULT 'LOW',
            summary     TEXT
        );
        CREATE TABLE IF NOT EXISTS cache (
            hash        TEXT PRIMARY KEY,
            ts          DATETIME DEFAULT CURRENT_TIMESTAMP,
            data_json   TEXT
        );
        CREATE TABLE IF NOT EXISTS bookmarks (
            id          INTEGER PRIMARY KEY AUTOINCREMENT,
            target      TEXT,
            ttype       TEXT,
            ts          DATETIME DEFAULT CURRENT_TIMESTAMP
        );
        CREATE TABLE IF NOT EXISTS notes (
            id          INTEGER PRIMARY KEY AUTOINCREMENT,
            target      TEXT,
            body        TEXT,
            ts          DATETIME DEFAULT CURRENT_TIMESTAMP
        );
        CREATE TABLE IF NOT EXISTS shares (
            id          INTEGER PRIMARY KEY AUTOINCREMENT,
            target      TEXT NOT NULL,
            token       TEXT NOT NULL UNIQUE,
            data_json   TEXT,
            ts          DATETIME DEFAULT CURRENT_TIMESTAMP
        );
        CREATE INDEX IF NOT EXISTS idx_scans_ts     ON scans(ts);
        CREATE INDEX IF NOT EXISTS idx_scans_target ON scans(target);
        CREATE INDEX IF NOT EXISTS idx_notes_target ON notes(target);
        CREATE INDEX IF NOT EXISTS idx_shares_token ON shares(token);
        """)


# ── Scans ──────────────────────────────────────────────────────────────────

def save_scan(target: str, ttype: str, data_json: str,
              score: int = 0, level: str = "LOW") -> None:
    """Save a completed scan. data_json is the JSON-serialised engine results."""
    summary = f"type={ttype} score={score} level={level}"
    with sqlite3.connect(DB_PATH) as c:
        c.execute(
            "INSERT INTO scans (target, ttype, score, level, summary) VALUES (?,?,?,?,?)",
            (target, ttype, score, level, summary),
        )


def get_history(limit: int = 20) -> list[tuple]:
    """Return rows: (id, ts, target, ttype, score, level, summary)."""
    with sqlite3.connect(DB_PATH) as c:
        return c.execute(
            "SELECT id, ts, target, ttype, score, level, summary "
            "FROM scans ORDER BY ts DESC LIMIT ?",
            (limit,),
        ).fetchall()


# ── Cache ──────────────────────────────────────────────────────────────────

def get_cached(target: str) -> tuple | None:
    """Return (hash, ts, data_json) if cache is fresh (<6h), else None."""
    h = hashlib.sha256(target.encode()).hexdigest()
    with sqlite3.connect(DB_PATH) as c:
        row = c.execute(
            "SELECT hash, ts, data_json FROM cache WHERE hash=?", (h,)
        ).fetchone()
    if row:
        try:
            age = datetime.now() - datetime.fromisoformat(row[1])
            if age < timedelta(hours=6):
                return row   # (hash, ts, data_json)
        except Exception:
            pass
    return None


def set_cache(target: str, data_json: str) -> None:
    """Store pre-serialised JSON string in cache."""
    h = hashlib.sha256(target.encode()).hexdigest()
    with sqlite3.connect(DB_PATH) as c:
        c.execute(
            "INSERT OR REPLACE INTO cache (hash, ts, data_json) VALUES (?,?,?)",
            (h, datetime.now().isoformat(), data_json),
        )


# ── Bookmarks ──────────────────────────────────────────────────────────────

def add_bookmark(target: str, ttype: str = "") -> None:
    with sqlite3.connect(DB_PATH) as c:
        c.execute(
            "INSERT INTO bookmarks (target, ttype) VALUES (?,?)", (target, ttype)
        )


def get_bookmarks() -> list[tuple]:
    """Return rows: (id, target, ttype, ts)."""
    with sqlite3.connect(DB_PATH) as c:
        return c.execute(
            "SELECT id, target, ttype, ts FROM bookmarks ORDER BY ts DESC"
        ).fetchall()


def delete_bookmark(bm_id: int) -> None:
    with sqlite3.connect(DB_PATH) as c:
        c.execute("DELETE FROM bookmarks WHERE id=?", (bm_id,))


def get_target_history(target: str, limit: int = 30) -> list[tuple]:
    """Return chronological score history for a specific target."""
    with sqlite3.connect(DB_PATH) as c:
        return c.execute(
            "SELECT id, ts, score, level FROM scans WHERE target=? ORDER BY ts ASC LIMIT ?",
            (target, limit),
        ).fetchall()


def get_watched_targets() -> list[dict]:
    """Return bookmarked targets with their most recent scan data."""
    with sqlite3.connect(DB_PATH) as c:
        bookmarks = c.execute(
            "SELECT DISTINCT target, ttype, ts FROM bookmarks ORDER BY ts DESC"
        ).fetchall()
        result = []
        for bm in bookmarks:
            latest = c.execute(
                "SELECT ts, score, level FROM scans WHERE target=? ORDER BY ts DESC LIMIT 1",
                (bm[0],)
            ).fetchone()
            result.append({
                "target":        bm[0],
                "ttype":         bm[1],
                "bookmarked_at": bm[2],
                "last_scan":     latest[0] if latest else None,
                "score":         latest[1] if latest else 0,
                "level":         latest[2] if latest else "UNKNOWN",
            })
        return result


# ── Notes ──────────────────────────────────────────────────────────────────

def add_note(target: str, body: str) -> None:
    safe_body = html.escape(body[:10_000])  # cap length and escape HTML entities
    with sqlite3.connect(DB_PATH) as c:
        c.execute(
            "INSERT INTO notes (target, body) VALUES (?,?)", (target, safe_body)
        )


def get_notes(target: str) -> list[tuple]:
    """Return rows: (id, target, body, ts)."""
    with sqlite3.connect(DB_PATH) as c:
        return c.execute(
            "SELECT id, target, body, ts FROM notes WHERE target=? ORDER BY ts DESC",
            (target,),
        ).fetchall()


# ── Shares ─────────────────────────────────────────────────────────────────

def create_share(target: str, token: str, data_json: str) -> None:
    """Insert a new shareable report into the shares table."""
    with sqlite3.connect(DB_PATH) as c:
        c.execute(
            "INSERT INTO shares (target, token, data_json) VALUES (?,?,?)",
            (target, token, data_json),
        )


def get_share(token: str) -> tuple | None:
    """Return (id, target, token, data_json, ts) for the given token, or None."""
    with sqlite3.connect(DB_PATH) as c:
        return c.execute(
            "SELECT id, target, token, data_json, ts FROM shares WHERE token=?",
            (token,),
        ).fetchone()


# ── Stats ──────────────────────────────────────────────────────────────────

def stats() -> dict:
    with sqlite3.connect(DB_PATH) as c:
        total   = c.execute("SELECT COUNT(*) FROM scans").fetchone()[0]
        today   = c.execute(
            "SELECT COUNT(*) FROM scans WHERE date(ts)=date('now')"
        ).fetchone()[0]
        unique  = c.execute(
            "SELECT COUNT(DISTINCT target) FROM scans"
        ).fetchone()[0]
        critical = c.execute(
            "SELECT COUNT(*) FROM scans WHERE score>=70"
        ).fetchone()[0]
    return {"total": total, "today": today, "unique_targets": unique, "critical": critical}


# ── Migrate old DB schema if needed ────────────────────────────────────────

def _migrate():
    """Safe migration: rename columns that changed between schema versions."""
    try:
        with sqlite3.connect(DB_PATH) as c:
            cols = {r[1] for r in c.execute("PRAGMA table_info(scans)").fetchall()}
            # Old schema had 'target_type' instead of 'ttype'
            if "target_type" in cols and "ttype" not in cols:
                c.executescript("""
                ALTER TABLE scans RENAME TO scans_old;
                CREATE TABLE scans (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    ts DATETIME DEFAULT CURRENT_TIMESTAMP,
                    target TEXT NOT NULL,
                    ttype  TEXT,
                    score  INTEGER DEFAULT 0,
                    level  TEXT DEFAULT 'LOW',
                    summary TEXT
                );
                INSERT INTO scans (id, ts, target, ttype, score, level)
                    SELECT id, ts, target, target_type, score, level FROM scans_old;
                DROP TABLE scans_old;
                """)
            # Old cache had 'data' instead of 'data_json'
            cache_cols = {r[1] for r in c.execute("PRAGMA table_info(cache)").fetchall()}
            if "data" in cache_cols and "data_json" not in cache_cols:
                c.executescript("""
                ALTER TABLE cache RENAME TO cache_old;
                CREATE TABLE cache (
                    hash TEXT PRIMARY KEY,
                    ts   DATETIME DEFAULT CURRENT_TIMESTAMP,
                    data_json TEXT
                );
                INSERT INTO cache (hash, ts, data_json)
                    SELECT hash, ts, data FROM cache_old;
                DROP TABLE cache_old;
                """)
            # Old bookmarks had no ttype column
            bm_cols = {r[1] for r in c.execute("PRAGMA table_info(bookmarks)").fetchall()}
            if "ttype" not in bm_cols and "target" in bm_cols:
                c.execute("ALTER TABLE bookmarks ADD COLUMN ttype TEXT DEFAULT ''")
    except Exception:
        pass   # Never crash on migration


_migrate()
init()
