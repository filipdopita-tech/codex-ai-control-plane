"""Filtering engine — whitelist/blacklist regex + dedupe + freshness.

Convention: whitelist hits = positive score; blacklist hits = negative weight (×2).
Card passes if `score >= min_score` (default 1) — t.j. minimálně 1 whitelist hit
bez převažujících blacklist hits."""
from __future__ import annotations

import re
from typing import List, Optional


def _card_text(card: dict) -> str:
    return " ".join(str(card.get(k, "")) for k in ("title", "company", "snippet", "location")) + " " + " ".join(card.get("tags", []))


def apply_filters(
    cards: List[dict],
    whitelist: Optional[List[str]] = None,
    blacklist: Optional[List[str]] = None,
    exclude_companies: Optional[List[str]] = None,
    min_score: int = 1,
) -> List[dict]:
    """Filter scraped cards. Returns sorted (score desc) list with `_score` attached."""
    wl = [re.compile(p, re.I) for p in (whitelist or [])]
    bl = [re.compile(p, re.I) for p in (blacklist or [])]
    excl = set((c.lower() for c in (exclude_companies or [])))

    out: List[dict] = []
    for c in cards:
        comp = c.get("company", "").lower()
        if comp in excl:
            continue
        text = _card_text(c)
        wl_hits = sum(1 for r in wl if r.search(text))
        bl_hits = sum(1 for r in bl if r.search(text))
        score = wl_hits - 2 * bl_hits
        # Whitelist mandatory pokud is configured
        if wl and wl_hits == 0:
            continue
        # Hard exclude pokud blacklist převažuje whitelist
        if bl_hits > 0 and (not wl or wl_hits <= bl_hits):
            continue
        if score < min_score:
            continue
        c2 = dict(c)
        c2["_score"] = score
        c2["_wl_hits"] = wl_hits
        c2["_bl_hits"] = bl_hits
        out.append(c2)

    out.sort(key=lambda x: -x.get("_score", 0))
    return out


def dedupe(cards: List[dict]) -> List[dict]:
    """Remove duplicate cards by jobad_id, fall back na title+company composite key."""
    seen = set()
    out: List[dict] = []
    for c in cards:
        key = (c.get("jobad_id") or "") + "|" + (c.get("title") or "").lower().strip() + "|" + (c.get("company") or "").lower().strip()
        if key in seen or key == "||":
            continue
        seen.add(key)
        out.append(c)
    return out


def filter_by_keywords(cards: List[dict], must_contain: List[str]) -> List[dict]:
    """Quick AND filter — všechny keywords musí být v textu cardu."""
    pats = [re.compile(p, re.I) for p in must_contain]
    return [c for c in cards if all(p.search(_card_text(c)) for p in pats)]


def filter_by_location(cards: List[dict], locations: List[str]) -> List[dict]:
    """Filter podle location keyword (Praha, Brno, ...)."""
    if not locations:
        return cards
    pats = [re.compile(re.escape(l), re.I) for l in locations]
    return [c for c in cards if any(p.search(c.get("location", "")) for p in pats)]
