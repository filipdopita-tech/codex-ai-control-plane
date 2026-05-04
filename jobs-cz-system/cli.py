#!/usr/bin/env python3
"""jobs.cz scraping CLI — Filipův entry point.

Subcommands:
  search    — ad-hoc search (`jobs search -q marketing -l praha --pages 5`)
  run       — run saved search by name (`jobs run it-leadership`)
  list      — list saved searches
  run-all   — run all saved searches sequentially (cron entry)
  show      — show latest results for a saved search

Output:
  /root/jobs-cz/results/{YYYY-MM-DD}/{name}/
    raw.json         — všechny scraped cards (před filterem)
    filtered.json    — po whitelist/blacklist
    filtered.csv     — for Excel review
    leads.csv        — pivot per company (warm outbound list)
    summary.md       — top picks + insights
"""
from __future__ import annotations

import argparse
import csv
import json
import sys
from datetime import datetime
from pathlib import Path

ROOT = Path(__file__).resolve().parent
SAVED = ROOT / "searches"
RESULTS = ROOT / "results"
sys.path.insert(0, str(ROOT))

from scraper.search import search  # noqa: E402
from scraper.filters import apply_filters, dedupe  # noqa: E402
from scraper.leads import to_leads, write_leads_csv  # noqa: E402
from scraper.notifier import push  # noqa: E402
from scraper.stats import collect_today, collect_week, top_companies_today, render_dashboard  # noqa: E402
from scraper.enrich import enrich_detail_top, enrich_leads_with_ares  # noqa: E402

OBSIDIAN_DASHBOARD = Path("/mac/Documents/OneFlow-Vault/00-Claude-Dashboard/Jobs-CZ-Dashboard.md")
SESSION_PATH = "/root/.credentials/jobs_cz_session.json"


# ---------- helpers ----------

def _today() -> str:
    return datetime.now().strftime("%Y-%m-%d")


def _slug(name: str) -> str:
    return "".join(c if c.isalnum() or c in "-_" else "-" for c in name.lower()).strip("-")[:60]


def _save_results(name: str, cards: list, filtered: list) -> Path:
    out = RESULTS / _today() / _slug(name)
    out.mkdir(parents=True, exist_ok=True)
    (out / "raw.json").write_text(
        json.dumps(cards, ensure_ascii=False, indent=2), encoding="utf-8"
    )
    (out / "filtered.json").write_text(
        json.dumps(filtered, ensure_ascii=False, indent=2), encoding="utf-8"
    )
    _write_csv(filtered, out / "filtered.csv")
    leads = to_leads(filtered)
    write_leads_csv(leads, out / "leads.csv")
    _write_summary(out / "summary.md", name, cards, filtered, leads)
    return out


def _write_csv(rows: list, path: Path) -> None:
    if not rows:
        path.write_text("# žádné výsledky po filtraci\n", encoding="utf-8")
        return
    keys = ["title", "company", "location", "salary", "posted", "url", "_score", "snippet"]
    with open(path, "w", encoding="utf-8", newline="") as f:
        w = csv.DictWriter(f, fieldnames=keys, extrasaction="ignore")
        w.writeheader()
        w.writerows(rows)


def _write_summary(path: Path, name: str, cards: list, filtered: list, leads: list) -> None:
    lines = [
        f"# jobs.cz | {name} | {datetime.now().strftime('%Y-%m-%d %H:%M')}",
        "",
        f"- **Scraped**: {len(cards)} inzerátů",
        f"- **Filtered**: {len(filtered)} po whitelist/blacklist",
        f"- **Unique companies**: {len(leads)}",
        "",
        "## Top 10 firem (podle skóre + počtu otevřených pozic)",
        "",
        "| # | Firma | Pozic | Score | Lokality |",
        "|---|---|---|---|---|",
    ]
    for i, l in enumerate(leads[:10], 1):
        lines.append(
            f"| {i} | {l['company']} | {l['open_positions']} | {l['best_score']} | {l['locations'][:60]} |"
        )
    lines.extend(["", "## Top 20 inzerátů (po skóre)", ""])
    for c in filtered[:20]:
        lines.append(
            f"- **{c.get('title', '?')}** — {c.get('company', '?')} | {c.get('location', '-')} | {c.get('salary', '-')}"
        )
        if c.get("url"):
            lines.append(f"  - {c['url']}")
        if c.get("snippet"):
            lines.append(f"  - _{c['snippet'][:200]}_")
    path.write_text("\n".join(lines), encoding="utf-8")


def _diff_with_prev(name: str, filtered_today: list) -> list:
    """Vrať seznam jobad_id které jsou v dnešním filteru ale ne v žádném předchozím."""
    today = _today()
    today_ids = {c.get("jobad_id", "") for c in filtered_today if c.get("jobad_id")}
    prev_ids: set = set()
    for d in sorted(RESULTS.glob("*"), reverse=True):
        if d.name == today or not d.is_dir():
            continue
        f = d / _slug(name) / "filtered.json"
        if f.exists():
            try:
                prev = json.loads(f.read_text(encoding="utf-8"))
                for c in prev:
                    if c.get("jobad_id"):
                        prev_ids.add(c["jobad_id"])
            except Exception:
                pass
        if len(prev_ids) > 5000:
            break
    return [c for c in filtered_today if c.get("jobad_id", "") in (today_ids - prev_ids)]


# ---------- subcommands ----------

def cmd_search(args) -> None:
    print(f"[SEARCH] query={args.query!r} location={args.location or '-'} pages={args.pages}")
    cards = search(
        args.query,
        location=args.location,
        max_pages=args.pages,
        use_session=not args.no_session,
    )
    cards = dedupe(cards)
    print(f"[FETCHED] {len(cards)} unique cards")

    wl = [s.strip() for s in args.whitelist.split(",")] if args.whitelist else []
    bl = [s.strip() for s in args.blacklist.split(",")] if args.blacklist else []
    if wl or bl:
        filtered = apply_filters(cards, whitelist=wl, blacklist=bl)
    else:
        filtered = list(cards)
    print(f"[FILTERED] {len(filtered)} after filters")

    out = _save_results(args.name or args.query, cards, filtered)
    print(f"[OUT] {out}")
    print(f"  → leads.csv  ({len(to_leads(filtered))} firem)")
    print(f"  → filtered.csv ({len(filtered)} inzerátů)")
    print(f"  → summary.md")

    if not args.no_notify and filtered:
        push(
            f"jobs.cz: {args.name or args.query}",
            f"Search hotov.\nScraped: {len(cards)}\nFiltered: {len(filtered)}\nLeads: {len(to_leads(filtered))}\n→ {out}",
            tags=["briefcase"],
            priority=3,
        )


def cmd_run_saved(args) -> None:
    f = SAVED / f"{args.name}.json"
    if not f.exists():
        print(f"[ERROR] saved search '{args.name}' nenalezen v {SAVED}")
        print(f"  Dostupné: {[p.stem for p in SAVED.glob('*.json')]}")
        sys.exit(2)
    cfg = json.loads(f.read_text(encoding="utf-8"))
    print(f"[RUN] {cfg['name']} — query={cfg.get('query')!r}")
    cards = search(
        cfg["query"],
        location=cfg.get("location"),
        max_pages=cfg.get("max_pages", 10),
        use_session=cfg.get("use_session", True),
    )
    cards = dedupe(cards)
    filtered = apply_filters(
        cards,
        whitelist=cfg.get("whitelist"),
        blacklist=cfg.get("blacklist"),
        exclude_companies=cfg.get("exclude_companies"),
        min_score=cfg.get("min_score", 1),
    )
    print(f"[FETCHED] {len(cards)} | [FILTERED] {len(filtered)}")
    out = _save_results(cfg["name"], cards, filtered)
    diff_new = _diff_with_prev(cfg["name"], filtered)
    print(f"[NEW vs prev] {len(diff_new)} brand-new listings")
    print(f"[OUT] {out}")

    if filtered:
        title = f"jobs.cz: {cfg['name']}"
        if diff_new:
            title += f" — {len(diff_new)} nových"
        body = (
            f"Total {len(filtered)} match z {len(cards)} scraped\n"
            f"Unique firem: {len(to_leads(filtered))}\n"
            f"Brand-new od minulého běhu: {len(diff_new)}\n"
            f"→ {out}"
        )
        push(
            title,
            body,
            tags=["briefcase", "sparkles" if diff_new else "mag"],
            priority=4 if diff_new else 3,
        )


def cmd_list(args) -> None:
    print(f"Saved searches v {SAVED}:\n")
    for f in sorted(SAVED.glob("*.json")):
        try:
            cfg = json.loads(f.read_text(encoding="utf-8"))
            wl = cfg.get("whitelist", []) or []
            print(f"  • {f.stem:30s}  query={str(cfg.get('query'))[:40]!r:42s}  wl={len(wl)} patterns")
        except Exception as e:
            print(f"  • {f.stem:30s}  [ERROR parse: {e}]")


def cmd_run_all(args) -> None:
    files = sorted(SAVED.glob("*.json"))
    print(f"[RUN-ALL] {len(files)} saved searches")
    failed = []
    for f in files:
        print(f"\n=== {f.stem} ===")
        try:
            args2 = argparse.Namespace(name=f.stem)
            cmd_run_saved(args2)
        except Exception as e:
            print(f"[FAIL] {f.stem}: {e}")
            failed.append(f.stem)
    print(f"\n[RUN-ALL DONE] {len(files) - len(failed)}/{len(files)} OK")
    if failed:
        push(
            f"jobs.cz: run-all selhalo {len(failed)}/{len(files)}",
            f"Failed: {', '.join(failed)}",
            tags=["warning"],
            priority=4,
        )


def cmd_show(args) -> None:
    """Zobraz nejnovější výsledky pro daný saved search."""
    name_slug = _slug(args.name)
    days = sorted(RESULTS.glob("*"), reverse=True)
    for d in days:
        candidate = d / name_slug / "summary.md"
        if candidate.exists():
            print(f"=== {candidate} ===\n")
            print(candidate.read_text(encoding="utf-8"))
            return
    print(f"[ERROR] žádné výsledky pro '{args.name}' v {RESULTS}")


def cmd_stats(args) -> None:
    """Cross-search dashboard — dnes + 7-day trend + top firmy."""
    md = render_dashboard(RESULTS, ntfy_history=args.days)
    print(md)
    # Optionally write to Obsidian (silent fail pokud /mac neni mount)
    try:
        if OBSIDIAN_DASHBOARD.parent.exists():
            OBSIDIAN_DASHBOARD.write_text(md, encoding="utf-8")
            print(f"\n[OBSIDIAN] {OBSIDIAN_DASHBOARD}")
    except Exception as e:
        print(f"\n[OBSIDIAN ERR] {e}")


def cmd_enrich_today(args) -> None:
    """ARES enrichment všech leads.csv dnes → leads_enriched.csv."""
    today_dir = RESULTS / _today()
    if not today_dir.exists():
        print(f"[ERROR] dnes ještě neproběhl scraping ({today_dir})")
        sys.exit(2)
    total = 0
    for sub in sorted(today_dir.glob("*")):
        if not sub.is_dir():
            continue
        leads_f = sub / "leads.csv"
        if not leads_f.exists():
            continue
        with open(leads_f, encoding="utf-8") as f:
            leads = list(csv.DictReader(f))
        if not leads:
            continue
        print(f"[ENRICH] {sub.name} — {len(leads)} firem (ARES lookup)")
        # Limit per saved search aby se nezatěžovalo ARES API (max 50 per saved)
        max_n = min(len(leads), args.limit)
        sample = leads[:max_n]
        enriched = enrich_leads_with_ares(sample)
        # Write enriched
        out_f = sub / "leads_enriched.csv"
        if enriched:
            keys = list(enriched[0].keys())
            with open(out_f, "w", encoding="utf-8", newline="") as f:
                w = csv.DictWriter(f, fieldnames=keys, extrasaction="ignore")
                w.writeheader()
                w.writerows(enriched)
            matched = sum(1 for e in enriched if e.get("ares_ico"))
            print(f"  → {out_f}  ({matched}/{len(enriched)} matched v ARES)")
            total += matched
    print(f"\n[DONE] ARES match total: {total}")


def cmd_export_all(args) -> None:
    """Sloučí leads ze všech saved searches dnešního dne do master leads list."""
    today_dir = RESULTS / _today()
    if not today_dir.exists():
        print(f"[ERROR] dnes ještě neproběhl scraping ({today_dir})")
        sys.exit(2)
    all_leads = []
    seen = set()
    for sub in sorted(today_dir.glob("*")):
        leads_file = sub / "leads.csv"
        if not leads_file.exists():
            continue
        with open(leads_file, encoding="utf-8") as f:
            r = csv.DictReader(f)
            for row in r:
                key = row.get("company", "").lower().strip()
                if key in seen:
                    continue
                seen.add(key)
                row["source_search"] = sub.name
                all_leads.append(row)
    if not all_leads:
        print("[NO LEADS]")
        return
    all_leads.sort(key=lambda x: -int(x.get("best_score", 0) or 0))
    out_path = today_dir / "MASTER_LEADS.csv"
    keys = list(all_leads[0].keys())
    with open(out_path, "w", encoding="utf-8", newline="") as f:
        w = csv.DictWriter(f, fieldnames=keys, extrasaction="ignore")
        w.writeheader()
        w.writerows(all_leads)
    print(f"[OUT] {out_path}  —  {len(all_leads)} unique firem napříč všemi saved searches")


# ---------- main ----------

def main() -> None:
    p = argparse.ArgumentParser(prog="jobs", description="jobs.cz scraping CLI — Filip OneFlow")
    sub = p.add_subparsers(dest="cmd", required=True)

    sp = sub.add_parser("search", help="ad-hoc search")
    sp.add_argument("-q", "--query", required=True, help="search keyword (může obsahovat mezery)")
    sp.add_argument("-l", "--location", default=None, help="město / okres (např. praha)")
    sp.add_argument("--pages", type=int, default=5, help="max stránek (default 5)")
    sp.add_argument("--whitelist", default="", help="comma-sep regex patterns (must match)")
    sp.add_argument("--blacklist", default="", help="comma-sep regex patterns (excluded)")
    sp.add_argument("--name", default=None, help="output folder name")
    sp.add_argument("--no-session", action="store_true", help="skip Filip's logged-in session")
    sp.add_argument("--no-notify", action="store_true")
    sp.set_defaults(func=cmd_search)

    sp = sub.add_parser("run", help="run saved search by name")
    sp.add_argument("name")
    sp.set_defaults(func=cmd_run_saved)

    sp = sub.add_parser("list", help="list saved searches")
    sp.set_defaults(func=cmd_list)

    sp = sub.add_parser("run-all", help="run all saved searches (cron entry)")
    sp.set_defaults(func=cmd_run_all)

    sp = sub.add_parser("show", help="show latest summary for saved search")
    sp.add_argument("name")
    sp.set_defaults(func=cmd_show)

    sp = sub.add_parser("export-all", help="merge today's leads → MASTER_LEADS.csv")
    sp.set_defaults(func=cmd_export_all)

    sp = sub.add_parser("stats", help="cross-search dashboard (dnes + trend + top firmy)")
    sp.add_argument("--days", type=int, default=7, help="historical trend window (days)")
    sp.set_defaults(func=cmd_stats)

    sp = sub.add_parser("enrich-today", help="ARES IČO/sídlo/NACE enrichment leads dnes")
    sp.add_argument("--limit", type=int, default=50, help="max firem per saved search (API politeness)")
    sp.set_defaults(func=cmd_enrich_today)

    args = p.parse_args()
    args.func(args)


if __name__ == "__main__":
    main()
