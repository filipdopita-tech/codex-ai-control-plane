"""Pivot scraped listings → firm-level lead list (1 row / company).

Filip = nabízí AI agent služby / fundraising / DD. Firmy které hledají X pozici =
warm signál (mají budget, hiring intent, growing). Tento module agregátí inzeráty
do leads listu pro outbound."""
from __future__ import annotations

import csv
from collections import defaultdict
from pathlib import Path
from typing import Dict, List


def to_leads(cards: List[dict]) -> List[dict]:
    """Group cards by company → 1 lead row per company."""
    by_co: Dict[str, dict] = defaultdict(lambda: {
        "positions": [],
        "locations": set(),
        "salaries": [],
        "best_score": 0,
        "best_warm": 0,
        "warm_signals": set(),
        "urls": [],
        "snippets": [],
        "portals": set(),
        "jobad_ids": [],
        "emails": [],
        "phones": [],
        "company_url": "",
        "description_excerpts": [],
    })
    for c in cards:
        co = c.get("company", "").strip() or "Neznámá firma"
        b = by_co[co]
        b["positions"].append(c.get("title", ""))
        if c.get("location"):
            b["locations"].add(c["location"])
        if c.get("salary"):
            b["salaries"].append(c["salary"])
        if c.get("url"):
            b["urls"].append(c["url"])
        if c.get("snippet"):
            b["snippets"].append(c["snippet"][:150])
        if c.get("source_portal"):
            b["portals"].add(c["source_portal"])
        if c.get("jobad_id"):
            b["jobad_ids"].append(c["jobad_id"])
        b["best_score"] = max(b["best_score"], c.get("_score", 0))
        b["best_warm"] = max(b["best_warm"], int(c.get("_warm_score", 0) or 0))
        for sig in (c.get("_warm_signals") or []):
            b["warm_signals"].add(sig)
        if c.get("contact_email") and c["contact_email"] not in b["emails"]:
            b["emails"].append(c["contact_email"])
        if c.get("contact_phone") and c["contact_phone"] not in b["phones"]:
            b["phones"].append(c["contact_phone"])
        if c.get("company_url") and not b["company_url"]:
            b["company_url"] = c["company_url"]
        if c.get("description"):
            excerpt = c["description"][:200]
            if excerpt and excerpt not in b["description_excerpts"]:
                b["description_excerpts"].append(excerpt)

    leads: List[dict] = []
    for co, info in by_co.items():
        positions_unique = sorted(set(p for p in info["positions"] if p))
        leads.append({
            "company": co,
            "open_positions": len(info["positions"]),
            "unique_titles": len(positions_unique),
            "positions": " | ".join(positions_unique[:8]),
            "locations": ", ".join(sorted(info["locations"]))[:200],
            "salaries": " | ".join(set(s for s in info["salaries"] if s))[:200],
            "best_score": info["best_score"],
            "warm_score": info["best_warm"],
            "warm_signals": ", ".join(sorted(info["warm_signals"]))[:200],
            "portals_seen": ", ".join(sorted(info["portals"])) or "jobs.cz",
            "contact_email": info["emails"][0] if info["emails"] else "",
            "contact_emails_all": " | ".join(info["emails"][:3]),
            "contact_phone": info["phones"][0] if info["phones"] else "",
            "company_url": info["company_url"],
            "first_url": info["urls"][0] if info["urls"] else "",
            "all_urls": " | ".join(info["urls"][:5]),
            "description_excerpt": (info["description_excerpts"][0] if info["description_excerpts"] else "")[:300],
            "snippets_combined": " || ".join(info["snippets"][:3])[:500],
        })
    leads.sort(key=lambda x: (-x["warm_score"], -x["best_score"], -x["open_positions"]))
    return leads


def write_leads_csv(leads: List[dict], path: Path) -> None:
    if not leads:
        Path(path).write_text("# žádné leads — search nevrátil žádné firmy po filtraci\n", encoding="utf-8")
        return
    keys = list(leads[0].keys())
    with open(path, "w", encoding="utf-8", newline="") as f:
        w = csv.DictWriter(f, fieldnames=keys, extrasaction="ignore")
        w.writeheader()
        w.writerows(leads)
