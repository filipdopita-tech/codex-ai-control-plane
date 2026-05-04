"""Cross-search analytics — kolik firem napříč všemi saved searches dnes,
top 10 podle skóre, growth proti vchorejšku, source mix."""
from __future__ import annotations

import csv
import json
from collections import defaultdict
from datetime import datetime, timedelta
from pathlib import Path
from typing import Dict, List


def collect_today(results_root: Path) -> Dict[str, dict]:
    """Vrátí dict {date_str → {search_name → metrics}}."""
    today = datetime.now().strftime("%Y-%m-%d")
    today_dir = results_root / today
    out: Dict[str, dict] = {}
    if not today_dir.exists():
        return out
    for sub in sorted(today_dir.glob("*")):
        if not sub.is_dir():
            continue
        raw_f = sub / "raw.json"
        filt_f = sub / "filtered.json"
        leads_f = sub / "leads.csv"
        if not raw_f.exists():
            continue
        try:
            raw = json.loads(raw_f.read_text(encoding="utf-8"))
            filt = json.loads(filt_f.read_text(encoding="utf-8")) if filt_f.exists() else []
            leads_count = 0
            if leads_f.exists():
                with open(leads_f, encoding="utf-8") as f:
                    leads_count = sum(1 for _ in csv.DictReader(f))
            out[sub.name] = {
                "scraped": len(raw),
                "filtered": len(filt),
                "leads": leads_count,
                "top_score": max((c.get("_score", 0) for c in filt), default=0),
            }
        except Exception:
            continue
    return out


def collect_week(results_root: Path, days: int = 7) -> List[Dict[str, str | int]]:
    """Trend per den za posledních N dní."""
    today = datetime.now()
    out = []
    for i in range(days - 1, -1, -1):
        d = (today - timedelta(days=i)).strftime("%Y-%m-%d")
        d_dir = results_root / d
        if not d_dir.exists():
            out.append({"date": d, "scraped": 0, "filtered": 0, "leads": 0, "searches": 0})
            continue
        scraped = filtered = leads = 0
        n = 0
        for sub in d_dir.glob("*"):
            if not sub.is_dir():
                continue
            raw_f = sub / "raw.json"
            filt_f = sub / "filtered.json"
            leads_f = sub / "leads.csv"
            if not raw_f.exists():
                continue
            try:
                scraped += len(json.loads(raw_f.read_text(encoding="utf-8")))
                if filt_f.exists():
                    filtered += len(json.loads(filt_f.read_text(encoding="utf-8")))
                if leads_f.exists():
                    with open(leads_f, encoding="utf-8") as f:
                        leads += sum(1 for _ in csv.DictReader(f))
                n += 1
            except Exception:
                continue
        out.append({"date": d, "scraped": scraped, "filtered": filtered, "leads": leads, "searches": n})
    return out


def top_companies_today(results_root: Path, limit: int = 25) -> List[dict]:
    """Top X firem napříč všemi searches dnes (highest score, dedup by name)."""
    today = datetime.now().strftime("%Y-%m-%d")
    today_dir = results_root / today
    if not today_dir.exists():
        return []
    by_company: Dict[str, dict] = {}
    for sub in sorted(today_dir.glob("*")):
        if not sub.is_dir():
            continue
        leads_f = sub / "leads.csv"
        if not leads_f.exists():
            continue
        with open(leads_f, encoding="utf-8") as f:
            for row in csv.DictReader(f):
                co = (row.get("company") or "").strip()
                if not co:
                    continue
                score = int(row.get("best_score", 0) or 0)
                pos = int(row.get("open_positions", 0) or 0)
                existing = by_company.get(co)
                existing_score = int(existing.get("best_score", 0) or 0) if existing else -1
                if not existing or score > existing_score:
                    new_row = dict(row)
                    new_row["source_searches"] = sub.name
                    new_row["best_score"] = score
                    by_company[co] = new_row
                else:
                    # Append source search
                    src = existing.get("source_searches", "")
                    if sub.name not in src:
                        existing["source_searches"] = src + ", " + sub.name
                    existing["open_positions"] = int(existing.get("open_positions", 0) or 0) + pos
    rows = list(by_company.values())
    rows.sort(key=lambda x: (-int(x.get("best_score", 0) or 0), -int(x.get("open_positions", 0) or 0)))
    return rows[:limit]


def render_dashboard(results_root: Path, ntfy_history: int = 7) -> str:
    """Generuje markdown dashboard pro Obsidian / terminál."""
    today = datetime.now().strftime("%Y-%m-%d %H:%M")
    today_data = collect_today(results_root)
    week_data = collect_week(results_root, days=ntfy_history)
    top = top_companies_today(results_root, limit=20)

    lines = [
        f"# jobs.cz Daily Dashboard | {today}",
        "",
        "## Today's runs",
        "",
        "| Search | Scraped | Filtered | Leads | Top score |",
        "|---|---|---|---|---|",
    ]
    if not today_data:
        lines.append("| _žádné runs dnes_ | 0 | 0 | 0 | - |")
    else:
        total_scraped = total_filtered = total_leads = 0
        for name, m in sorted(today_data.items()):
            lines.append(f"| {name} | {m['scraped']} | {m['filtered']} | {m['leads']} | {m['top_score']} |")
            total_scraped += m["scraped"]
            total_filtered += m["filtered"]
            total_leads += m["leads"]
        lines.append(f"| **TOTAL** | **{total_scraped}** | **{total_filtered}** | **{total_leads}** | - |")

    lines.extend([
        "",
        f"## 7-day trend",
        "",
        "| Date | Searches | Scraped | Filtered | Leads |",
        "|---|---|---|---|---|",
    ])
    for d in week_data:
        lines.append(f"| {d['date']} | {d['searches']} | {d['scraped']} | {d['filtered']} | {d['leads']} |")

    lines.extend([
        "",
        f"## Top {len(top)} firem dnes (cross-search, podle nejvyššího skóre + počtu pozic)",
        "",
        "| # | Firma | Pozic | Score | Source searches | Lokality |",
        "|---|---|---|---|---|---|",
    ])
    for i, r in enumerate(top, 1):
        co = r.get("company", "?")
        pos = r.get("open_positions", "0")
        score = r.get("best_score", "0")
        src = r.get("source_searches", "")
        loc = (r.get("locations") or "")[:60]
        lines.append(f"| {i} | {co} | {pos} | {score} | {src} | {loc} |")

    return "\n".join(lines)
