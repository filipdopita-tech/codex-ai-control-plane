"""Cross-search analytics — kolik firem napříč všemi saved searches dnes,
top 10 podle skóre, growth proti vchorejšku, source mix."""
from __future__ import annotations

import csv
import json
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


def top_companies_today(results_root: Path, limit: int = 25, by: str = "warm") -> List[dict]:
    """Top X firem napříč všemi searches dnes.

    by: "warm" (warm_score primary), "score" (raw _score), "positions" (count)
    """
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
                warm = int(row.get("warm_score", 0) or 0)
                score = int(row.get("best_score", 0) or 0)
                pos = int(row.get("open_positions", 0) or 0)
                existing = by_company.get(co)
                existing_warm = int(existing.get("warm_score", 0) or 0) if existing else -1
                if not existing or warm > existing_warm:
                    new_row = dict(row)
                    new_row["source_searches"] = sub.name
                    new_row["warm_score"] = warm
                    new_row["best_score"] = score
                    by_company[co] = new_row
                else:
                    sources = existing.get("source_searches", "")
                    if sub.name not in sources:
                        existing["source_searches"] = sources + ", " + sub.name
                    existing["open_positions"] = int(existing.get("open_positions", 0) or 0) + pos
    rows = list(by_company.values())
    if by == "score":
        rows.sort(key=lambda x: (-int(x.get("best_score", 0) or 0), -int(x.get("open_positions", 0) or 0)))
    elif by == "positions":
        rows.sort(key=lambda x: (-int(x.get("open_positions", 0) or 0), -int(x.get("warm_score", 0) or 0)))
    else:
        rows.sort(key=lambda x: (-int(x.get("warm_score", 0) or 0), -int(x.get("best_score", 0) or 0), -int(x.get("open_positions", 0) or 0)))
    return rows[:limit]


def warm_signal_breakdown(results_root: Path) -> Dict[str, int]:
    """Aggregate warm signal counts across today's leads."""
    today = datetime.now().strftime("%Y-%m-%d")
    today_dir = results_root / today
    counters = {"urgent": 0, "senior_role": 0, "salary_disclosed": 0, "reposted": 0,
                "cross_portal": 0, "high_warm_50": 0, "total_leads": 0}
    if not today_dir.exists():
        return counters
    seen_companies = set()
    for sub in sorted(today_dir.glob("*")):
        if not sub.is_dir():
            continue
        leads_f = sub / "leads.csv"
        if not leads_f.exists():
            continue
        with open(leads_f, encoding="utf-8") as f:
            for row in csv.DictReader(f):
                co = (row.get("company") or "").strip().lower()
                if not co or co in seen_companies:
                    continue
                seen_companies.add(co)
                counters["total_leads"] += 1
                sigs = (row.get("warm_signals") or "")
                if "urgent" in sigs:
                    counters["urgent"] += 1
                if "senior_role" in sigs:
                    counters["senior_role"] += 1
                if "salary_disclosed" in sigs:
                    counters["salary_disclosed"] += 1
                if "reposted" in sigs:
                    counters["reposted"] += 1
                if "cross_portal" in sigs:
                    counters["cross_portal"] += 1
                if int(row.get("warm_score", 0) or 0) >= 50:
                    counters["high_warm_50"] += 1
    return counters


def render_dashboard(results_root: Path, ntfy_history: int = 7) -> str:
    """Generuje markdown dashboard pro Obsidian / terminál."""
    today = datetime.now().strftime("%Y-%m-%d %H:%M")
    today_data = collect_today(results_root)
    week_data = collect_week(results_root, days=ntfy_history)
    top = top_companies_today(results_root, limit=20, by="warm")
    warm_breakdown = warm_signal_breakdown(results_root)

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
        f"## Warm signal breakdown ({warm_breakdown.get('total_leads', 0)} unique firem)",
        "",
        f"- 🔥 **High warm (score >=50)**: {warm_breakdown.get('high_warm_50', 0)}",
        f"- ⚡ **Urgent keywords**: {warm_breakdown.get('urgent', 0)}",
        f"- 👑 **Senior role (CMO/CFO/Head of/Director/Lead)**: {warm_breakdown.get('senior_role', 0)}",
        f"- 💰 **Salary disclosed**: {warm_breakdown.get('salary_disclosed', 0)}",
        f"- 🔁 **Reposted (still hiring 2+ days)**: {warm_breakdown.get('reposted', 0)}",
        f"- 🌐 **Cross-portal (jobs.cz + prace.cz / startupjobs)**: {warm_breakdown.get('cross_portal', 0)}",
        "",
        f"## Top {len(top)} HOT LEADS dnes (warm_score primary)",
        "",
        "| # | Firma | Pozic | Warm | Score | Signals | Portals | Source searches |",
        "|---|---|---|---|---|---|---|---|",
    ])
    for i, r in enumerate(top, 1):
        co = (r.get("company") or "?")[:40]
        pos = r.get("open_positions", "0")
        warm = r.get("warm_score", "0")
        score = r.get("best_score", "0")
        sigs = (r.get("warm_signals") or "")[:50]
        portals = (r.get("portals_seen") or "")[:25]
        sources = (r.get("source_searches") or "")[:35]
        lines.append(f"| {i} | {co} | {pos} | {warm} | {score} | {sigs} | {portals} | {sources} |")

    # Cross-portal champions section
    cross = [r for r in top if "," in (r.get("portals_seen") or "")]
    if cross:
        lines.extend([
            "",
            f"## Cross-portal champions ({len(cross)} firmy hledající napříč 2+ portály = silný pain signal)",
            "",
            "| Firma | Pozic | Warm | Portals | Pozice |",
            "|---|---|---|---|---|",
        ])
        for r in cross[:15]:
            co = (r.get("company") or "?")[:35]
            pos = r.get("open_positions", "0")
            warm = r.get("warm_score", "0")
            portals = r.get("portals_seen", "")
            positions = (r.get("positions") or "")[:60]
            lines.append(f"| {co} | {pos} | {warm} | {portals} | {positions} |")

    return "\n".join(lines)
