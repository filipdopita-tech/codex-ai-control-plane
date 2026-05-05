"""SQLite history DB — fast cross-day queries for diff + warm scoring.

Schema:
  jobads      — every filtered card seen on any day, upserted by jobad_id
  companies   — per-company aggregate (first/last seen, lifetime jobads, portals)
  daily_runs  — audit log of run-all invocations

Used by:
  - filters/scoring.py for warm signal computation (repost count, age, recency)
  - cli.py cmd_diff for fast cross-day company/jobad lookup
  - cli.py cmd_stats for top warm leads dashboard
"""
from __future__ import annotations

import sqlite3
from datetime import date, datetime
from pathlib import Path
from typing import Dict, List, Optional

DB_DEFAULT = Path("/root/jobs-cz/data/history.db")

SCHEMA = """
CREATE TABLE IF NOT EXISTS jobads (
    jobad_id        TEXT PRIMARY KEY,
    source_portal   TEXT NOT NULL,
    company         TEXT,
    company_lower   TEXT,
    title           TEXT,
    location        TEXT,
    salary          TEXT,
    employment_type TEXT,
    posted_text     TEXT,
    url             TEXT,
    score_raw       INTEGER DEFAULT 0,
    source_search   TEXT,
    first_seen      TEXT NOT NULL,
    last_seen       TEXT NOT NULL,
    seen_count      INTEGER DEFAULT 1,
    seen_dates_json TEXT DEFAULT '[]'
);
CREATE INDEX IF NOT EXISTS idx_jobads_company ON jobads(company_lower);
CREATE INDEX IF NOT EXISTS idx_jobads_last_seen ON jobads(last_seen);
CREATE INDEX IF NOT EXISTS idx_jobads_portal ON jobads(source_portal);

CREATE TABLE IF NOT EXISTS companies (
    company_lower         TEXT PRIMARY KEY,
    company               TEXT,
    first_seen            TEXT NOT NULL,
    last_seen             TEXT NOT NULL,
    total_jobads_lifetime INTEGER DEFAULT 0,
    portals_seen_json     TEXT DEFAULT '[]'
);
CREATE INDEX IF NOT EXISTS idx_companies_last_seen ON companies(last_seen);

CREATE TABLE IF NOT EXISTS daily_runs (
    id              INTEGER PRIMARY KEY AUTOINCREMENT,
    run_at          TEXT NOT NULL,
    saved_search    TEXT,
    portal          TEXT,
    cards_scraped   INTEGER,
    cards_filtered  INTEGER,
    leads_unique    INTEGER,
    new_companies   INTEGER,
    new_jobads      INTEGER
);
"""


def get_conn(db_path: Path = DB_DEFAULT) -> sqlite3.Connection:
    db_path.parent.mkdir(parents=True, exist_ok=True)
    conn = sqlite3.connect(str(db_path))
    conn.row_factory = sqlite3.Row
    conn.executescript(SCHEMA)
    return conn


def _today() -> str:
    return date.today().isoformat()


def upsert_cards(conn: sqlite3.Connection, cards: List[dict], source_search: str) -> Dict[str, int]:
    """Upsert filtered cards into jobads + companies. Returns counts dict."""
    today = _today()
    new_jobads = 0
    new_companies = 0
    cur = conn.cursor()
    for c in cards:
        jid = c.get("jobad_id") or ""
        if not jid:
            continue
        company = (c.get("company") or "").strip()
        company_lower = company.lower()
        portal = c.get("source_portal") or "jobs.cz"

        # jobad upsert
        row = cur.execute("SELECT seen_count, seen_dates_json, first_seen FROM jobads WHERE jobad_id=?", (jid,)).fetchone()
        if row is None:
            new_jobads += 1
            cur.execute(
                """INSERT INTO jobads (jobad_id, source_portal, company, company_lower, title, location,
                   salary, employment_type, posted_text, url, score_raw, source_search,
                   first_seen, last_seen, seen_count, seen_dates_json)
                   VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,1,?)""",
                (jid, portal, company, company_lower, c.get("title", ""), c.get("location", ""),
                 c.get("salary", ""), c.get("employment_type", ""), c.get("posted", ""),
                 c.get("url", ""), int(c.get("_score", 0) or 0), source_search,
                 today, today, f'["{today}"]')
            )
        else:
            import json as _j
            dates = _j.loads(row["seen_dates_json"] or "[]")
            if today not in dates:
                dates.append(today)
            cur.execute(
                """UPDATE jobads SET last_seen=?, seen_count=?, seen_dates_json=?
                   WHERE jobad_id=?""",
                (today, len(dates), _j.dumps(dates), jid)
            )

        # company upsert
        if company_lower:
            crow = cur.execute("SELECT first_seen, total_jobads_lifetime, portals_seen_json FROM companies WHERE company_lower=?", (company_lower,)).fetchone()
            if crow is None:
                new_companies += 1
                cur.execute(
                    """INSERT INTO companies (company_lower, company, first_seen, last_seen,
                       total_jobads_lifetime, portals_seen_json)
                       VALUES (?,?,?,?,1,?)""",
                    (company_lower, company, today, today, f'["{portal}"]')
                )
            else:
                import json as _j
                portals = set(_j.loads(crow["portals_seen_json"] or "[]"))
                portals.add(portal)
                cur.execute(
                    """UPDATE companies SET last_seen=?,
                       total_jobads_lifetime=total_jobads_lifetime+1,
                       portals_seen_json=?
                       WHERE company_lower=?""",
                    (today, _j.dumps(sorted(portals)), company_lower)
                )
    conn.commit()
    return {"new_jobads": new_jobads, "new_companies": new_companies, "total_processed": len(cards)}


def log_run(conn: sqlite3.Connection, saved_search: str, portal: str,
            scraped: int, filtered: int, leads: int, new_co: int, new_jb: int) -> None:
    conn.execute(
        """INSERT INTO daily_runs (run_at, saved_search, portal, cards_scraped, cards_filtered,
           leads_unique, new_companies, new_jobads) VALUES (?,?,?,?,?,?,?,?)""",
        (datetime.utcnow().isoformat(), saved_search, portal, scraped, filtered, leads, new_co, new_jb)
    )
    conn.commit()


def get_jobad_history(conn: sqlite3.Connection, jobad_id: str) -> Optional[dict]:
    row = conn.execute("SELECT * FROM jobads WHERE jobad_id=?", (jobad_id,)).fetchone()
    return dict(row) if row else None


def get_company_history(conn: sqlite3.Connection, company_lower: str) -> Optional[dict]:
    row = conn.execute("SELECT * FROM companies WHERE company_lower=?", (company_lower,)).fetchone()
    return dict(row) if row else None


def cross_portal_companies(conn: sqlite3.Connection) -> List[dict]:
    """Companies seen on 2+ portals — strongest pain signal."""
    rows = conn.execute(
        """SELECT company, portals_seen_json, total_jobads_lifetime, last_seen
           FROM companies
           WHERE json_array_length(portals_seen_json) >= 2
           ORDER BY total_jobads_lifetime DESC"""
    ).fetchall()
    return [dict(r) for r in rows]


if __name__ == "__main__":
    conn = get_conn()
    print("schema OK")
    print("jobads:    ", conn.execute("SELECT COUNT(*) FROM jobads").fetchone()[0])
    print("companies: ", conn.execute("SELECT COUNT(*) FROM companies").fetchone()[0])
    print("daily_runs:", conn.execute("SELECT COUNT(*) FROM daily_runs").fetchone()[0])
