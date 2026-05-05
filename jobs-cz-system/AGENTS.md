# jobs-cz-system — Codex / Claude Operating Rule

**Scope**: Python scraping + filtering + outreach pipeline for CZ job-boards reverse-recruiter use case (jobs.cz, prace.cz, StartupJobs).

## Inheritance

This project inherits root rules from:
- **Codex side**: `~/Desktop/Codex/AGENTS.md` (anti-halluci handoff contract, telemetry, verify gate)
- **Claude side**: `~/CLAUDE.md` (Codex Bridge Autopilot, model routing, completion mandate)

Bridge synergy stack (Wave 1+2+3, 2026-05-05 closure) ensures multi-file edits in this project trigger nudge → delegation → telemetry capture per the global rules.

## Project-specific notes

- **Login session**: Flash VPS holds `/root/.credentials/jobs_cz_session.json` (storage_state, expires ~2027-04). Re-login command in root memory `project_jobs_cz_login_2026_05_04.md`.
- **Scrapers**: `scraper/leads.py`, `scraper/stats.py`, `scraper/scoring.py`, `scraper/multi.py`, `scraper/startupjobs.py`, `scraper/prace_cz.py`, `scraper/history.py`. Multi-portal dispatcher: `scraper/multi.py:53-83`.
- **Daily refresh**: launchd `com.oneflow.icp-daily-sheet` 06:50 Mac, refreshes Master ICP Sheet (11 tabs, 23 firem classified into 5 OneFlow segments).
- **History DB**: SQLite `data/history.db` for cross-day dedup queries.
- **Warm-signal scoring**: composite 0-100 from urgent/senior/salary/cross_portal/reposted signals (in scraper/scoring.py + duplicated v scraper/stats.py — known dup, see A1 review at `/tmp/jobs-cz-review.md`).

## Bridge delegation cheatsheet

```bash
# Lean mode (default, fast, narrow scope)
codex jobs-cz-system "<task>"

# Full mode (MCP/cloud/browser tasks)
OFS_CODEX_MODE=full codex jobs-cz-system "<task>"

# After delegation, verify gate runs automatically. Manual re-run:
ofs verify ~/Desktop/Codex/jobs-cz-system

# Today's bridge stats:
ofs bu today
```

## Reports & deliverables

- **A1 review** (2026-05-05): `/tmp/jobs-cz-review.md` — 7-file dead-code/error-handling/dup-logic audit
- **Master ICP Sheet**: Google Sheets `12LBNK...sBGjE` (11 tabs)
- **Memory pointers**:
  - `~/.claude/projects/-Users-filipdopita-Desktop-Codex/memory/project_jobs_cz_system_2026_05_04.md`
  - `~/.claude/projects/-Users-filipdopita-Desktop-Codex/memory/project_jobs_cz_phase2_2026_05_04.md`
  - `~/.claude/projects/-Users-filipdopita-Desktop-Codex/memory/project_jobs_cz_icp_sheet_2026_05_04.md`

## Operating constraints

1. **No FB/Meta cookies** in scrapers (per `~/.claude/rules/fb-scrape-safety.md`)
2. **No paid Google API** (per `~/.claude/rules/cost-zero-tolerance.md`)
3. **Respect `data/history.db`** — append-only, never DROP TABLE without explicit instruction
4. **Storage state on Flash, not Mac** — re-auth requires SSH to `root@10.77.0.1`
5. **Polite concurrency**: jobs.cz max 1 req/2s, prace.cz max 1 req/3s, StartupJobs unrestricted (JSON API)

— Dopita, 2026-05-05 (Wave 3 closure)
