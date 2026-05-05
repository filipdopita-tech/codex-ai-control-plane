"""Warm signal scoring — augments raw score with cross-day pain signals.

Components (sum into _warm_score 0-100):
  +20  cross-portal: company seen on 2+ portals (jobs.cz + prace.cz + startupjobs ...)
  +15  repost: jobad seen 3+ times across days (still hiring = pain)
  +10  repost: jobad seen 2 times (re-listing)
  +15  urgency keyword in title or snippet (urgentně, ASAP, okamžitě, hned, naléhavě)
  +10  explicit salary disclosed (transparent budget = serious)
  +10  senior/lead/director/head/c-suite role
  + 5  recent (posted today / nová nabídka)
  +base raw_score * 5 (existing whitelist match strength)

Each card gets:
  _warm_score   int
  _warm_signals list[str]  e.g. ["cross_portal", "urgent", "senior_role"]
"""
from __future__ import annotations

import re
import sqlite3
from typing import Dict, List, Optional

URGENCY_RE = re.compile(
    r"\b(?:urgent\w*|asap|okamži\w*|hned|nalehav\w*|naléhav\w*|nutno|ihned|do\s*\d+\s*dn[ůi]|priorit\w*)\b",
    re.IGNORECASE,
)
SENIOR_RE = re.compile(
    r"\b(?:senior|lead|leader|head\s*of|chief|cto|cfo|coo|cmo|cro|vp\b|director|ředitel|reditel|principal|staff)\b",
    re.IGNORECASE,
)
RECENT_RE = re.compile(r"nov[áé]\s*nabídk|today|dnes|nedávn|nedavn", re.IGNORECASE)


def warm_score_one(card: dict, history_conn: Optional[sqlite3.Connection] = None) -> Dict:
    """Compute warm signal score + signal labels for a single card.

    Mutates card in-place: adds _warm_score (int) and _warm_signals (list).
    Returns dict for inspection.
    """
    score = 0
    signals: List[str] = []

    raw = int(card.get("_score", 0) or 0)
    score += min(raw * 5, 25)
    if raw >= 2:
        signals.append(f"raw_match_{raw}")

    text = " ".join([card.get("title", ""), card.get("snippet", ""), card.get("posted", "")])

    if URGENCY_RE.search(text):
        score += 15
        signals.append("urgent")

    if SENIOR_RE.search(card.get("title", "")):
        score += 10
        signals.append("senior_role")

    if RECENT_RE.search(text):
        score += 5
        signals.append("recent")

    if card.get("salary"):
        score += 10
        signals.append("salary_disclosed")

    # History-driven (require sqlite history)
    if history_conn is not None:
        jid = card.get("jobad_id")
        company_lower = (card.get("company", "") or "").strip().lower()

        if jid:
            row = history_conn.execute(
                "SELECT seen_count, seen_dates_json FROM jobads WHERE jobad_id=?", (jid,)
            ).fetchone()
            if row:
                sc = int(row[0])
                if sc >= 3:
                    score += 15
                    signals.append(f"reposted_{sc}d")
                elif sc == 2:
                    score += 10
                    signals.append("reposted_2d")

        if company_lower:
            crow = history_conn.execute(
                "SELECT portals_seen_json FROM companies WHERE company_lower=?", (company_lower,)
            ).fetchone()
            if crow:
                import json as _j
                portals = _j.loads(crow[0] or "[]")
                if len(portals) >= 2:
                    score += 20
                    signals.append("cross_portal")

    score = min(score, 100)
    card["_warm_score"] = score
    card["_warm_signals"] = signals
    return {"score": score, "signals": signals}


def score_cards(cards: List[dict], history_conn: Optional[sqlite3.Connection] = None) -> List[dict]:
    """Score every card in list; return list (mutates each card)."""
    for c in cards:
        warm_score_one(c, history_conn)
    return cards


def warm_summary(cards: List[dict]) -> Dict:
    """Aggregate warm signals across a card set for reporting."""
    out = {
        "total": len(cards),
        "urgent": 0,
        "senior_role": 0,
        "salary_disclosed": 0,
        "reposted": 0,
        "cross_portal": 0,
        "high_warm": 0,  # score >= 50
    }
    for c in cards:
        sigs = c.get("_warm_signals", [])
        if "urgent" in sigs:
            out["urgent"] += 1
        if "senior_role" in sigs:
            out["senior_role"] += 1
        if "salary_disclosed" in sigs:
            out["salary_disclosed"] += 1
        if any(s.startswith("reposted") for s in sigs):
            out["reposted"] += 1
        if "cross_portal" in sigs:
            out["cross_portal"] += 1
        if int(c.get("_warm_score", 0) or 0) >= 50:
            out["high_warm"] += 1
    return out
