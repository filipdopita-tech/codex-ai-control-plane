# Reverse-Recruiter System — Mapping na Filipův Ekosystém

**Date:** 2026-05-04 | **Audience:** Filip Dopita / OneFlow | **Cíl:** Postavit reverse-recruiter pipeline (scrape CZ job-boardy → enrich firma+kontakt → AI match → outreach → reply track → GHL CRM) s **maximálním re-use** existujících assetů a **minimálním novým kódem**.

---

## Executive summary (5 klíčových insightů)

1. **70% pipeline existuje** — Filip má `cold-outreach-v3` (6-fázový enrichment+send), `lead-ops` (mode-based scoring engine), `leadgen` (natural-query → Excel), `scrapling` (anti-bot framework), `algorithm-recall/recipes/` (ARES fuzzy + contact dedup). Reverse-recruiter pipeline = **scraping layer (NEW) + scoring twist (NEW) + zbytek re-use**.

2. **Žádný conductor/hermes-style daemon pro tento use case neexistuje** — Filip má Hermes Agent (multi-platform gateway) a Conductor pattern, ale žádný systemd timer pro denní job-board scrape. **Build: launchd timer na Mac (denně 06:30) NEBO systemd timer na Flash (preferred — VPS běží 24/7)**.

3. **Send infrastructure je hotová** — Postfix dopita@oneflow.cz (per project_email_dopita_oneflow_2026_05_02), DMARC reject + DNSSEC + MTA-STS enforce (per project_email_security_top_2026_05_03). **POZOR**: nepoužívat dopita@ pro mass outreach — protect Filip's primary identity. **Doporučení**: použít sister inbox jako outreach@oneflow.cz (sister DMARC enabled per W7 closure) NEBO oneflow-team.cz domain pro reverse-recruiter campaigns.

4. **AI matching layer = Claude API** — Filip má Max sub (Sonnet 4.6 default, Opus 4.7 pro stakes, Haiku 4.5 pro batch). OpenRouter free models pro >1000 lead batches (deepseek-r1:free, qwen-3-coder:free). **Žádný OSS pitch generator nepřekoná Claude + OneFlow brand voice prompt**.

5. **GSD project nelze startovat bez ICP definition** — Filip má 3 ICP definovaný v cold-outreach-v3 (`ceo_sro_50plus`, `cfo_500plus`, `founder_b2b`). **Pro reverse-recruiter musí přidat 4. ICP**: `firma_hledajici_role` (firma s aktivním job postingem, role typu AI Engineer / Marketing Manager / SDR / DevOps, repost ≥2× v 30 dnech, velikost 10-250 FTE).

---

## A. Architektura systému

### Komponenty + flow

```
┌─────────────────────────────────────────────────────────────┐
│  L1 SCRAPING LAYER — denní cron, Flash VPS                  │
│  ┌──────────┐  ┌──────────┐  ┌────────────┐  ┌──────────┐  │
│  │ Jobs.cz  │  │ Práce.cz │  │ StartupJobs│  │ Profesia │  │
│  │ Scrapling│  │ Scrapling│  │ Bearer API │  │ Stealthy │  │
│  └─────┬────┘  └────┬─────┘  └─────┬──────┘  └────┬─────┘  │
└────────┼────────────┼──────────────┼───────────────┼────────┘
         └────────────┴──────────────┴───────────────┘
                              ▼
┌─────────────────────────────────────────────────────────────┐
│  L2 STORAGE — SQLite/DuckDB na Flash                        │
│  /root/reverse-recruiter/data/jobs.db                       │
│  Tables: job_postings, companies, contacts, sends, replies  │
└──────────────────────┬──────────────────────────────────────┘
                       ▼
┌─────────────────────────────────────────────────────────────┐
│  L3 ENRICHMENT — re-use cold-outreach-v3 waterfall          │
│  ARES → Justice → LinkedIn → Hunter → Apollo → SMTP verify  │
└──────────────────────┬──────────────────────────────────────┘
                       ▼
┌─────────────────────────────────────────────────────────────┐
│  L4 PAIN SCORING — NEW                                      │
│  - Repost detector (job_id reappears in N dní)              │
│  - Urgency lexicon (CZ: "urgentně", "ihned", "ASAP")        │
│  - Role→service mapping (AI Eng → Filip AI agents)          │
│  - Composite score 0-100                                    │
└──────────────────────┬──────────────────────────────────────┘
                       ▼
┌─────────────────────────────────────────────────────────────┐
│  L5 AI MATCH — Claude API                                   │
│  GIRL framework: JD parse → goal → service map → pitch      │
│  Sonnet 4.6 batch / Opus 4.7 top 50 / Haiku categorization  │
└──────────────────────┬──────────────────────────────────────┘
                       ▼
┌─────────────────────────────────────────────────────────────┐
│  L6 OUTREACH — Postfix outreach@oneflow.cz                  │
│  - Rate limit 50/den/sender first month                     │
│  - Multi-step sequence T+0/+3/+7/+14/+21                    │
│  - Reply tracking (IMAP poll → classify → GHL stage update) │
└──────────────────────┬──────────────────────────────────────┘
                       ▼
┌─────────────────────────────────────────────────────────────┐
│  L7 CRM SYNC — GHL API                                      │
│  Pipeline: Cold → Replied → Booked → Proposal → Closed      │
└──────────────────────┬──────────────────────────────────────┘
                       ▼
┌─────────────────────────────────────────────────────────────┐
│  L8 MONITORING — ntfy + Obsidian dashboard                  │
│  - High-score lead alert (composite >80)                    │
│  - Daily digest 22:00 (jobs scraped, leads added, replies)  │
│  - Weekly funnel review (Sundays 09:00)                     │
└─────────────────────────────────────────────────────────────┘
```

---

## B. Integrační body — komponenty

| # | Komponenta | Existující asset (path) | Gap (nové) | Complexity | Dependencies |
|---|---|---|---|---|---|
| 1 | Jobs.cz scraper | `~/.claude/skills/scrapling/recipes/competitor-monitor.py` (template) | Build `scrapers/jobs_cz.py` adapter | **M** | Scrapling MCP, robots.txt compliance |
| 2 | Práce.cz scraper | jako #1 | Build `scrapers/prace_cz.py` | **M** | Scrapling Fetcher |
| 3 | StartupJobs.cz integration | žádný (NEW) | Bearer API client `scrapers/startupjobs.py` | **S** | Filip request token na hello@startupjobs.cz |
| 4 | Profesia.cz scraper | jako #1 | Build `scrapers/profesia.py` (StealthyFetcher pro Cloudflare) | **M** | Scrapling 0.4.7 StealthyFetcher |
| 5 | Storage layer | žádný (NEW) | SQLite na Flash `/root/reverse-recruiter/data/jobs.db` | **S** | sqlite3, schema design |
| 6 | ARES enrichment | `~/.claude/skills/scrapling/recipes/ares-batch-enrich.py` ✓ | — | **N/A** | Re-use as-is |
| 7 | Justice + LinkedIn enrichment | `cold-outreach-v3` Phase 2 waterfall ✓ | — | **N/A** | Re-use as-is |
| 8 | Hunter + Apollo direct | `cold-outreach-v3` Phase 2 ✓ | — | **N/A** | Re-use; rate limit shared budget |
| 9 | SMTP verify | `cold-outreach-v3` smtp_verifier.py ✓ | — | **N/A** | Re-use |
| 10 | ARES fuzzy matching | `~/.claude/skills/algorithm-recall/recipes/ares-fuzzy.py` ✓ | — | **N/A** | Re-use |
| 11 | Contact dedup | `~/.claude/skills/algorithm-recall/recipes/contact-dedup.py` ✓ | — | **N/A** | Re-use (SHA-256+Bloom O(1)) |
| 12 | Repost detector | žádný (NEW) | `scoring/repost_detector.py` — same job_id reappears v N dní | **S** | jobs.db time-series |
| 13 | Urgency lexicon | žádný (NEW) | `scoring/urgency_lexicon.py` (CZ keyword list) | **S** | Custom regex/NLP |
| 14 | Role→service mapping | `~/.claude/expertise/agent-business-lifecycle.yaml` (pricing per service) ✓ | Build `scoring/role_to_service.py` | **M** | Filip service catalog mapping |
| 15 | Composite pain score | `lead-ops modes/_shared.md` (scoring framework) ✓ | Customize pro reverse-recruiter context | **S** | Re-use scoring logic, nová váha |
| 16 | JD parser | žádný (NEW) | `pitch/jd_parser.py` — Claude Haiku batch | **S** | Anthropic API |
| 17 | Intent mapper | žádný (NEW) | `pitch/intent_mapper.py` — Sonnet | **S** | Anthropic API |
| 18 | Personalizer | žádný (NEW), inspirace: cold-outreach-v3 Phase 3 | `pitch/personalizer.py` — Sonnet/Opus + brand voice prompt | **M** | Anthropic API + OneFlow brand rules |
| 19 | Postfix orchestrator | Postfix dopita@oneflow.cz ✓, **POZOR** preferuj `outreach@oneflow.cz` | Build send wrapper s rate limit | **S** | Postfix submission, sister inbox setup |
| 20 | Sequence engine (cadence) | `cold-outreach-v3` Phase 5+6 ✓ | Re-use, případně refine | **N/A** | Re-use |
| 21 | Reply tracker (IMAP) | `cold-outreach-v3` Phase 6 ✓ | Re-use IMAP poll | **N/A** | Re-use |
| 22 | GHL API wrapper | `~/.claude/expertise/crm-ghl.yaml` (config) ✓ | Build `crm/ghl_pusher.py` (idempotent) | **S** | GHL API token (~/.credentials/) |
| 23 | ntfy alerting | `~/scripts/automation/ntfy.sh` ✓ | Re-use | **N/A** | Re-use |
| 24 | Obsidian dashboard | `~/Documents/OneFlow-Vault/00-Claude-Dashboard/` ✓ | Add `Reverse-Recruiter-Dashboard.md` | **S** | Markdown template + cron refresh |
| 25 | systemd timer (daily scrape) | `~/scripts/automation/auto-promote.sh` ✓ (per W2 closure) | Spawn 4 timers (1 per portál) | **S** | systemctl --user, OnCalendar=*-*-* 06:30 |

**Total estimate:**
- New code: 11 komponent (12 + 13 + 14 + 16-19 + 22 + 24 + 25 + 5)
- Reused: 14 komponent
- Estimated MVP: **~12 dní** (per OSS cherry-pick blueprint)

---

## C. Daemon strategy

### Scheduling (Flash VPS, ne Mac)

Důvod: Mac sleeps, Flash běží 24/7, lepší pro denní cron.

**systemd timer pattern** (per `auto-promote.sh` workflow-routing):

```
/etc/systemd/system/reverse-recruiter-scrape.service
/etc/systemd/system/reverse-recruiter-scrape.timer
```

**timer config:**
```
[Timer]
OnCalendar=*-*-* 06:30:00 Europe/Prague
Persistent=true
RandomizedDelaySec=15min   # avoid same-second scrape pattern
```

**rate limit per portál** (in scraper code):
- Jobs.cz: 1 req/sec (per CZ boards research, robots.txt allows)
- Práce.cz: 1 req/sec
- StartupJobs.cz: API rate limit (Filip request — typically 100/min)
- Profesia.cz: 1 req/2 sec (respect robots.txt spirit, even though forbidden)

### Conductor / Hermes integration

**Conductor pattern** (orchestrator daemon na Flash, per memory ref): job-board scrape může být registrovaný jako Conductor task. Ověřit zda Conductor existuje (`find /Users/filipdopita/Desktop/Codex -name "conductor*"` během implementation).

**Hermes Agent** (multi-platform gateway, INSTALLED 2026-04-30): natural-language interface pro Filipa.
- Filip via Telegram: "ukaž top 10 leadů z dneška" → Hermes routuje na DB query
- Filip via WhatsApp: "pošli mi týdenní digest" → Hermes triggeruje report

**Pattern**: scraper produkuje data, Hermes je read-only frontend pro Filipa.

### Error handling + retry

- Per portál: 3 retries s exponential backoff (1s, 5s, 30s)
- Po 3× selhání → ntfy alert "scraper {portal} down" → Filip rozhodne
- Network errors logované do `/var/log/reverse-recruiter/scrape-errors.log` s rotací (logrotate weekly)

---

## D. GSD project plan

### Milestone název

**`reverse-recruiter-cz` — Q3 2026 lead-gen pipeline**

### Phases (5)

**Phase 1: Scraping foundation** (Week 1, ~4 dny)
- Scope: 4 adaptery (Jobs.cz, Práce.cz, StartupJobs API, Profesia.cz) + SQLite storage + systemd timer
- Dependencies: žádné (greenfield)
- Output: `~/Desktop/Codex/reverse-recruiter/scrapers/`, `data/jobs.db` populated 1k+ records denně
- Smoke test: `sqlite3 jobs.db "SELECT COUNT(*) FROM job_postings WHERE scraped_at > date('now','-1 day')"` → >100

**Phase 2: Pain scoring + ICP filter** (Week 2, ~3 dny)
- Scope: Repost detector + urgency lexicon + role→service mapping + composite score
- Dependencies: Phase 1 (need 7+ dní dat pro repost detection baseline)
- Output: `scoring/`, `data/scored_companies.csv` (top 100 P0 leads denně)
- Smoke test: composite score distribution sanity (10% >70, 40% >40, 50% <40)

**Phase 3: Enrichment + AI pitch** (Week 2-3, ~3 dny)
- Scope: Hookni cold-outreach-v3 enrichment waterfall + custom Claude pitch generator + brand voice check
- Dependencies: Phase 2 (need scored leads as input)
- Output: `pitch/`, `data/enriched_leads.csv` s personalized pitch per lead
- Smoke test: 50 sample pitches manuálně checknout — 0 banned words, brand voice alignment >90%

**Phase 4: Outreach + reply handling** (Week 3-4, ~3 dny)
- Scope: Postfix outreach@oneflow.cz wrapper + sequence engine (re-use cold-outreach-v3) + IMAP reply tracker + GHL push
- Dependencies: Phase 3 (need ready-to-send pitches)
- Output: `send/`, `crm/`, GHL pipeline populated, daily send <50 first week
- Smoke test: send 5 test emails na vlastní inbox, verify deliverability + reply parsing

**Phase 5: Productization & retainer scale** (Week 5-8, ~4 dny + sales work)
- Scope: Obsidian dashboard + ntfy alerts + Hermes integration (read-only) + first 2-3 retainer klient closes
- Dependencies: Phase 4 PASS s pilot conversion >3,5%
- Output: `monitoring/`, `Reverse-Recruiter-Dashboard.md` v Vault, 2+ klient retainer signed
- Smoke test: dashboard shows real-time funnel state, ntfy fires na high-score lead

**Total milestone duration: ~5-8 týdnů (build 13 dní + 2 týdny pilot + sales)**

---

## E. First 24h pro Filipa — 5 konkrétních příkazů

```bash
# 1. Založit GSD milestone (5 min)
cd ~/Desktop/Codex
mkdir -p reverse-recruiter/{scrapers,scoring,pitch,send,crm,monitoring,data}
echo "# Reverse-Recruiter CZ — Milestone Q3 2026" > reverse-recruiter/README.md
# (alternativně: /gsd:new-milestone reverse-recruiter-cz)

# 2. Smoke test Scrapling proti Jobs.cz (5 min)
~/.venvs/scrapling/bin/python -c "
from scrapling.fetchers import Fetcher
p = Fetcher.get('https://www.jobs.cz/prace/', timeout=15)
print('status:', p.status, 'len:', len(p.body))
print('robots:', Fetcher.get('https://www.jobs.cz/robots.txt').body[:500])
"

# 3. Read Jobs.cz JSON-LD JobPosting schema (10 min)
~/.venvs/scrapling/bin/python -c "
from scrapling.fetchers import Fetcher
import re
p = Fetcher.get('https://www.jobs.cz/prace/?date=24h', timeout=15)
# Extract JSON-LD blocks
blocks = re.findall(r'<script type=\"application/ld\\+json\">(.*?)</script>', p.body, re.DOTALL)
print(f'JSON-LD blocks found: {len(blocks)}')
print('first block (300 chars):', blocks[0][:300] if blocks else 'NONE')
"

# 4. Smoke test ARES enrichment recipe (5 min)
~/.venvs/scrapling/bin/python ~/.claude/skills/scrapling/recipes/ares-batch-enrich.py --test
# (verify recipe exists; if not, ls ~/.claude/skills/scrapling/recipes/)

# 5. Pre-flight: ověř že outreach@oneflow.cz inbox existuje (5 min)
ssh root@10.77.0.1 "doveadm user outreach@oneflow.cz 2>&1 | head -5"
# pokud neexistuje → vytvořit přes /etc/dovecot/passwd nebo vsmtp config
```

**Co vznikne za soubory:**
- `~/Desktop/Codex/reverse-recruiter/` directory
- `~/Desktop/Codex/reverse-recruiter/README.md` (milestone scope)
- (Optional) GSD milestone struktura `.planning/milestones/reverse-recruiter-cz/`

**Smoke test critéria PASS:**
- Smoke 2: status 200, body >50KB, robots.txt readable
- Smoke 3: JSON-LD blocks >5, JobPosting schema present
- Smoke 4: ARES recipe exists, runs without error
- Smoke 5: outreach@oneflow.cz exists OR plan to create

---

## F. Risk mapping na rules

| Rule | Risk pro reverse-recruiter | Mitigation |
|---|---|---|
| `cost-zero-tolerance.md` (Google API ban) | LinkedIn Sales Navigator API costs ($79+/mo); Apollo paid tier; Hunter paid; ZoomInfo enterprise | **MITIGATE**: free tier first (Hunter 25/mo, Apollo 75 credits/mo). Žádné paid commit bez Filip svolení. ZADNY Gemini API. OpenRouter free pro batch (deepseek-r1:free, qwen-3-coder:free). |
| `fb-scrape-safety.md` | Tato pipeline NEZAHRNUJE FB/Meta scrape. ALE LinkedIn Voyager API per cold-outreach-v3 — risk podobný. | **MITIGATE**: LinkedIn jen via Sales Navigator API (paid, ToS-compliant) NEBO public profile bez login. NIKDY Filip's session cookies v automatizaci. |
| `oneflow-all.md` (banned words) | Pitch generation může produkovat banned words ("inovativní", "revoluční", "win-win", "synergie") | **MITIGATE**: Phase 3 brand voice check + banned words regex filter pre-send. Manual review prvních 50 pitches. |
| `anti-hallucination.md` | AI matching může halucinovat firma facts ("DSCR XYZ je 1.42" nebo "vaše společnost má 50 employees") | **MITIGATE**: Pitch templates use jen verifikovaná data z DB (ARES IČO, job posting text quoted verbatim). [VERIFIED] markers v pitch metadata. NIKDY claim co není v scrape. |
| `completion-mandate.md` | Pokud scrape selže, riziko "to nejde" frází | **MITIGATE**: 3-strike retry per portál. Pokud opravdu down → switch na alternative portál. Reportuj "X scraper down, fallback na Y, plán fix do 24h". |
| `prompt-completeness.md` | Multi-step pipeline = riziko skip steps | **MITIGATE**: TodoWrite per fáze (Filip workflow). GSD project breakdown explicit. |

**HARD-STOP zóny:**
- Send akce VŽDY vyžadují Filip explicit "spusť" — never auto-send mass batch (per `~/.claude/rules/hard-stop-zone.md` #2)
- Costy >100 Kč/měs vyžadují Filip svolení (per #1)
- DB schema migrace na production data = #3 (rare)
- Ne-relevantní pro #4 (FB/Meta) — pokud LinkedIn jen Sales Navigator API
- Strategy decision >100k Kč: pricing model retainer commit nad tímhle limitem ano (per #5)

---

## Open questions (Filip rozhodne)

1. **Send infrastructure**: použít existující `dopita@oneflow.cz` (risk reputation primary inbox) **NEBO** vytvořit dedikovaný `outreach@oneflow.cz` (clean reputation start, warm-up potřeba) **NEBO** sister domain `oneflow-team.cz`?
   - Recommendation: **outreach@oneflow.cz** (cleanest separation, sister DMARC enabled per W7 closure)

2. **AI pitch model routing**: 
   - Default Claude Sonnet 4.6 ($3 input / $15 output per Mtok)
   - High-stakes top 50/měs → Opus 4.7 ($15/$75)
   - Batch >1000 → OpenRouter free (deepseek-r1:free, $0)
   - Recommendation: **Sonnet default + Opus pro top 20% (composite >80) + free pro batch validation**

3. **GHL pipeline structure**:
   - Existující GHL pipeline má 5 stages? Vytvořit dedicated reverse-recruiter pipeline?
   - Recommendation: **Dedicated pipeline "Reverse-Recruiter CZ"** s 6 stages: Cold → Sent → Replied → Booked → Proposal → Closed/Lost

4. **ICP scope (kterých firem začít)**:
   - AI Engineer / ML Engineer roles → Filip AI agent service (best fit)
   - Marketing Manager / Performance Marketer → Filip Meta Ads agency
   - SDR / BDR → Filip outreach automation
   - Recommendation: **Start s AI Engineer ICP** (nejlepší margin + Filip moat) v Q1, expand do Marketing Q2

5. **Productization timing**:
   - Internal-only Y1 (Filip uses pro own lead-gen)
   - SaaS "JobSignal CZ" Y2 ($99/měs Pro tier)
   - Recommendation: **Internal Y1, decide SaaS based on first 6 měsíců retainer success**

6. **Legal counsel timing**:
   - Pre-pilot (Week 1, before scrape) — €2-5k cost, 2 týdny lead time
   - Post-pilot (Week 8, after pilot data) — riskantější ale cheaper if pilot fails
   - Recommendation: **Pre-pilot review** (per strategy.md compliance section, Article 6(f) clarity essential)

---

## Top 3 existing assets to reuse (urgency rank)

1. **`cold-outreach-v3` skill** — entire 6-fázový pipeline (ICP+ARES → enrichment → personalization → deliverability → send → followup). Re-use 90% as-is, jen Phase 1 input změnit z general ICP na "firma s active job posting + repost ≥2".

2. **`scrapling` skill + MCP** — anti-bot framework, recipes dir, venv ready. Build 4 nových recipes (jobs_cz, prace_cz, startupjobs, profesia) v `~/.claude/skills/scrapling/recipes/jobs/` directory.

3. **`algorithm-recall` recipes** — `ares-fuzzy.py` pro IČO dedup, `contact-dedup.py` pro O(1) "have I contacted before" check (SHA-256+Bloom). Critical pro >1k lead campaigns.

## Top 3 gaps to build (urgency rank)

1. **Scraper adapters per CZ portál** (4 files, ~4 dny) — žádný OSS repo nemá CZ adaptery. Postavit v Scrapling pattern.

2. **Pain scoring layer** (composite_score.py + 3 sub-scorers, ~3 dny) — repost detector + urgency lexicon + role→service mapping. Custom logic, žádný existing asset.

3. **AI pitch generator** (3 files: jd_parser, intent_mapper, personalizer, ~3 dny) — Claude API integration s OneFlow brand voice. Inferior OSS not worth.

## Suggested milestone

**Name:** `reverse-recruiter-cz`  
**Duration:** 5-8 týdnů (13 dní build + 2 týdny pilot + 2-3 týdny sales/legal)  
**Phases:** Scraping foundation (W1) → Pain scoring (W2) → Enrichment+AI pitch (W2-3) → Outreach+reply (W3-4) → Productization+scale (W5-8)

---

**Word count: 2,420 | Created: 2026-05-04 | Ecosystem-mapped: scrapling, cold-outreach-v3, lead-ops, leadgen, algorithm-recall, agent-business-lifecycle**

Dopita
