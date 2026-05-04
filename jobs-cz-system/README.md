# jobs.cz scraping system — Filip OneFlow

> Reverse-recruiter pipeline. Filip nabízí AI agenty / fundraising / DD služby. Firmy, které hledají IT/marketing/finance vedení = warm signál (mají budget, hiring intent, growing). Tento systém scraje `jobs.cz`, filtruje na relevantní pozice, pivot na firma-úroveň → leads.csv pro outbound.

## Stav (2026-05-04)

- ✅ Login k jobs.cz živý na Flash (`fdopita@email.cz`, session expirace ~2027-04)
- ✅ Scraper engine: Playwright + persistent session
- ✅ 4 saved searches: IT, marketing, finance, fundraising (každá s vlastní whitelist/blacklist regex)
- ✅ Filtrace + dedupe + lead pivot + diff (NEW od minulého běhu)
- ✅ ntfy push při novém matchi
- ✅ CLI: `jobs.sh search/run/list/run-all/show/export-all`
- ✅ Cron daily 06:30 — `refresh-all.sh` → všechny saved searches
- ✅ Output: dated složky `/root/jobs-cz/results/{YYYY-MM-DD}/{search-name}/` s raw.json + filtered.csv + leads.csv + summary.md

## Použití (Flash)

```bash
# List saved searches
/root/jobs-cz/jobs.sh list

# Ad-hoc search ("marketingový ředitel" v Praze, max 5 stránek)
/root/jobs-cz/jobs.sh search -q "marketingový ředitel" -l praha --pages 5

# Run saved search
/root/jobs-cz/jobs.sh run it-leadership

# Run všechny saved searches (cron entry)
/root/jobs-cz/jobs.sh run-all

# Show latest summary pro saved search
/root/jobs-cz/jobs.sh show it-leadership

# Merge dnešní leads ze všech searches → master CSV
/root/jobs-cz/jobs.sh export-all

# ARES enrichment — IČO/sídlo/NACE/právní forma pro dnes (max 30 firem per saved)
/root/jobs-cz/jobs.sh enrich-today --limit 30

# Cross-search dashboard (dnes + 7-day trend + top 20 firem)
# Auto-syncuje do Obsidian: ~/Documents/OneFlow-Vault/00-Claude-Dashboard/Jobs-CZ-Dashboard.md
/root/jobs-cz/jobs.sh stats
```

## Použití z Macu (přes SSH wrapper)

```bash
ssh root@10.77.0.1 '/root/jobs-cz/jobs.sh run marketing-leadership'
ssh root@10.77.0.1 '/root/jobs-cz/jobs.sh search -q "head of finance" --pages 3 --no-notify'
```

## Architektura

```
/root/jobs-cz/
├── scraper/
│   ├── search.py       Playwright + paginated fetch
│   ├── parser.py       BeautifulSoup → structured cards
│   ├── filters.py      whitelist/blacklist regex + dedupe
│   ├── leads.py        pivot per-company → leads CSV
│   └── notifier.py     ntfy push
├── searches/           saved JSON queries
│   ├── it-leadership.json
│   ├── marketing-leadership.json
│   ├── finance-banking.json
│   └── fundraising-capital.json
├── results/            dated output
│   └── {YYYY-MM-DD}/
│       └── {search-name}/
│           ├── raw.json
│           ├── filtered.json
│           ├── filtered.csv      ← Excel review
│           ├── leads.csv         ← per-firmu pivot pro outbound
│           └── summary.md        ← top picks + insights
├── scripts/
│   ├── refresh-all.sh  cron entry (denní)
│   └── install-cron.sh idempotent cron installer
├── cli.py              Python CLI (multi-subcommand)
├── jobs.sh             bash wrapper (resolves venv)
├── login.py            re-login (creates jobs_cz_session.json)
└── README.md
```

## Saved searches — schema

```json
{
  "name": "marketing-leadership",
  "description": "Co tahle saved search hledá",
  "query": "marketing",                ← jeden hlavní keyword (broad fetch)
  "max_pages": 10,
  "use_session": true,
  "min_score": 1,
  "whitelist": [                       ← regex patterns (case-insensitive)
    "marketing.*ředitel",
    "head of marketing",
    "CMO"
  ],
  "blacklist": [                       ← regex patterns (vyloučí)
    "junior",
    "stáž",
    "praktikant"
  ],
  "exclude_companies": []              ← lowercased company names
}
```

Score = `whitelist_hits − 2 × blacklist_hits`. Card prošel pokud `score >= min_score` (default 1).

## Přidat novou saved search

1. Vytvoř `searches/new-search-name.json` se schématem výše
2. Test: `/root/jobs-cz/jobs.sh run new-search-name`
3. Pokud OK, automaticky půjde do `run-all` (pickup-by-glob)

## Diff detection (NEW listings)

Při každém `run` skript porovná `jobad_id` z dnešního filteru s historií předchozích běhů (až 5000 IDs back). NEW = listing který nikdy předtím v historii nebyl. Push notifikace vystupují na priority 4 pokud `len(new_ids) > 0`.

## Output formáty

| File | Použití |
|---|---|
| `raw.json` | Surová data (před filtrem) — backup, debug |
| `filtered.json` | Po whitelist/blacklist — pro programové další zpracování |
| `filtered.csv` | Excel review jednotlivých inzerátů |
| `leads.csv` | **HLAVNÍ** — 1 řádek = 1 firma s počtem otevřených pozic, score, locations, urls |
| `summary.md` | Top 10 firem + top 20 inzerátů, čte se za 30s |
| `MASTER_LEADS.csv` (po `export-all`) | Sloučené leads ze všech saved searches |

## Bezpečnost

- Credentials v `/root/.credentials/jobs_cz.env` (chmod 600)
- Session storage_state v `/root/.credentials/jobs_cz_session.json` (chmod 600)
- Žádné automated apply / odeslání zprávy / write akce — HARD-STOP zóna #2
- Polite delay 1.5s mezi stránkami
- Headless Chromium s realistic UA + cs-CZ locale

## Re-login (když session expiruje, ~rok)

```bash
ssh root@10.77.0.1 '/root/.venvs/jobs-cz/bin/python /root/jobs-cz/login.py'
```

## Chain s ostatními skills

- `cold-outreach-v3` — leads.csv → ARES enrichment → email waterfall → Voss/Cialdini cold email
- `lead-ops` — full pipeline z leads.csv (ICP scoring, dedupe across sources)
- `agency-discovery-coach` — pre-call prep když Filip pojede na meeting s firmou z leads listu
- `dd-emitent` — pokud firma vydává dluhopisy nebo plánuje emisi, leads.csv → DD pipeline
