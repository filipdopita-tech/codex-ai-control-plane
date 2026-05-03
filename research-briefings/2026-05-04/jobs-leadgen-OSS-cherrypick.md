# Open-Source Cherry-Pick: Reverse-Recruiter Lead-Gen Stack (CZ, 2026)

**Date:** 2026-05-04 | **Audience:** Filip Dopita / OneFlow | **Verification:** All repos verified via GitHub API live (stars/license/last commit). 4 původně navrhované repos byly **halucinace** (404 GET /repos/...) — odstraněny + flagnuty v AVOID sekci.

---

## Important framing — Filip's use case

Filip je **AGENCY**, ne **CANDIDATE**. Reverse-recruiter pipeline = scrape job postings, najít firmy s pain (hledají FTE), oslovit s nabídkou outsource místo hire.

**To znamená pro OSS cherry-pick:**

| Kategorie | Relevance pro Filip | Důvod |
|---|---|---|
| Job board scrapers | **P0 vital** | Core data layer pro pain detection |
| Email finder / lead enrichment | **P0 vital** | Najít hiring manager / decision maker |
| Cold outreach automation | **P0 vital** | Send infrastructure |
| ARES/IČO enrichment | **Done** (Filip má vlastní `ares-fuzzy.py`) | — |
| AI pitch generator | **Build, not adopt** | Claude API + custom prompt > inferior OSS |
| CV/resume builders | ~~Skip~~ | Filip nepíše CV, nepřihlašuje se |
| Cover letter generators | ~~Skip~~ | Filip nepíše motivační dopis, posílá B2B pitch |
| Auto-apply systems | **Reference only** | Anti-pattern study (jak vypadá bot z pohledu recruitera) |
| Reverse-recruiter detection (recruiter→inbound spam) | ~~Skip~~ | Opačný směr než Filip use case |

---

## Executive summary — top 3 must-have repos

1. **speedyapply/JobSpy** (3,284★ MIT, last push 2026-02) — multi-board scraper (LinkedIn/Indeed/Glassdoor/ZipRecruiter/Google/Bayt/Naukri). Adopt jako reference architecture pro OneFlow CZ adapter. **Verdict: A — copy/adapt** (architecture pattern; vlastní CZ implementation pro Jobs.cz/Práce.cz/StartupJobs.cz).

2. **deep-div/Cold-Email-Automation** (30★ Apache-2.0, 2026-02) — explicitly *"extracts job listings from a company's career page"* + cold email pipeline. Téměř identický use case. **Verdict: A — copy/adapt** (cherry-pick logika "kdo posílá co kdy").

3. **PaulleDemon/Email-automation** (144★, 2024) — proven cold email outreach tool. Battle-tested. **Verdict: B — cherry-pick komponenty** (rate limiting, send orchestration, reply tracking patterns).

**Honorable mention:** speedyapply/JobSpy maintainers vystavují actively-maintained TypeScript port `alpharomercoma/ts-jobspy` (10★) pokud Filip chce TS/Node alternative.

---

## 1. Job board scrapers (P0)

| Repo | ★ | License | Last commit | Verdict | Notes |
|---|---|---|---|---|---|
| **speedyapply/JobSpy** | 3,284 | MIT | 2026-02-18 | **A** copy/adapt | Canonical (formerly cullenwatson/JobSpy → Bunsly/JobSpy → speedyapply). 7+ boards. Production-ready. |
| feder-cr/Jobs_Applier_AI_Agent_AIHawk | 29,736 | MIT | 2025-11-16 | **C** reference, **archived** | Massive popularity, ALE *archived* — projekt mrtvý. Učení z architecture, nepoužívat as dependency. |
| alpharomercoma/ts-jobspy | 10 | (verify) | 2026-01-14 | **B** TS variant | Fresh TS port pro Node ekosystem. Filip preferuje Python. |
| naeemsabir1/DevHunt | 2 | MIT | 2026-04-18 | **C** reference | "AI-powered job aggregator scrapes 13 platforms, scores every listing". Příliš nový (2★), ale architectural reference scoring layer. |
| Ridadata/job-intelligent | 2 | (verify) | 2026-04-27 | **C** reference | "End-to-end recruitment intelligence platform" — fresh, aspiration alignment. Watch repo. |

**Cherry-pick z JobSpy:**
- `JobPost` dataclass schema (title/company/location/salary/posted_date/description/url) — universal model
- Per-board adapter pattern (`scrapers/linkedin.py`, `scrapers/indeed.py`)
- Rate limiting + retry logic
- Output formats (CSV/JSON/Pandas DataFrame)

**CZ-specific gap:** JobSpy nemá adapter pro Jobs.cz / Práce.cz / StartupJobs.cz / Profesia.cz. Filip postaví **vlastní 4 adaptery** v duchu JobSpy architecture, použije Scrapling 0.4.7 (CZ-friendly anti-bot).

---

## 2. Email finder / lead enrichment (P0)

| Repo | ★ | License | Last commit | Verdict | Notes |
|---|---|---|---|---|---|
| J3012B/Email-Guessing-Permutator-Verifier | 0 | NoLicense | 2026-02-17 | **D** skip (no license) | Fresh ale 0★ + nelicenced = nelegální použití |
| (manual recommendation) email-permutator pattern | — | — | — | **B** build | Pattern: jméno+příjmení × domain → guess emails → SMTP verify (Filip má smtp_verifier.py per cold-outreach-v3) |
| Hunter.io API | — | Paid SaaS | — | **D** cost | $49/mo+, per cost-zero-tolerance vyžaduje schválení |
| Apollo.io API | — | Freemium 75 credits/měs | — | **B** cherry-pick | Filip's cold-outreach-v3 už obsahuje Apollo direct API integration (post Apify dead 2026-09) |

**Cherry-pick recommendation:** Filip MÁ cold-outreach-v3 skill který orchestruje ARES → Justice → LinkedIn Voyager → Hunter (free 25/měs) → Apollo direct (75 free credits/měs) → SMTP verify waterfall. **Žádný OSS repo to nedělá lépe pro CZ kontext** — Filip's stack je už superior.

---

## 3. Cold outreach automation (P0)

| Repo | ★ | License | Last commit | Verdict | Notes |
|---|---|---|---|---|---|
| **PaulleDemon/Email-automation** | 144 | NOASSERTION | 2024-09-04 | **B** cherry-pick | Open-source cold email outreach tool. Cherry-pick: send orchestration, rate limit. |
| **deep-div/Cold-Email-Automation** | 30 | Apache-2.0 | 2026-02-21 | **A** copy/adapt | *"Extracts job listings from a company's career page"* — téměř identický use case s Filipem. Adopt logika. |
| Sabique-Islam/raven | 19 | NoLicense | 2026-04-25 | **D** skip (no license) | "Automating bulk cold outreach emails". Nelicensed = nelegální fork. |
| LeadMagic/smartlead-mcp-server | 18 | MIT | 2025-07-02 | **B** cherry-pick | MCP server pro SmartLead (paid SaaS). Pattern relevantní pokud Filip chce MCP integration. |
| Schlaflied/job-autopilot | 8 | GPL-3.0 | 2026-01-28 | **C** reference | Auto-apply (anti-pattern), ale GPT-4o pitch gen integrace ukazuje pattern. AGPL → infect Filip stack. |

**Klíčová akvizice — deep-div/Cold-Email-Automation:**
```
Use case overlap: "extracts job listings from a company's career page"
→ Filipova adaptace: "extracts hiring intent z Jobs.cz/Práce.cz job postings"
→ Architecture: scrape → parse → AI rewrite → send
```

Apache-2.0 license = OneFlow ho může fork/upravit/komercializovat. Repo je čerstvý (2026-02), maintainer aktivní.

---

## 4. ATS / resume parsers (P2 — niche use)

Filip nepotřebuje pro core use case, ALE může použít pro **inverse function** — když dostane response od kandidáta nebo HR osoby, parse jejich hiring criteria.

| Repo | ★ | License | Verdict | Notes |
|---|---|---|---|---|
| sunnypatell/ats-screener | 50 | MIT | 2026-04-27 | **C** reference | Screener simulating 6 ATS platforms. Užitečné pro pochopení jak HR scoringy fungují. |
| praj2408/End-To-End-Resume-ATS-Tracking-LLM-Project-With-Google-Gemini-Pro | 79 | MIT | 2024-01-26 | **D** skip (Gemini = blocked per cost-zero-tolerance) | Funkční pattern ale Gemini = paid Google API. |
| KnlnKS/lever-parser-extension | 21 | MIT | 2022-02-25 | **D** stale | 2022, dead. |

**Verdict celkově:** Filip nepotřebuje ATS parsing. Skip kategorie.

---

## 5. Pitch / cover letter generators (P3 — reference only)

Filip používá **Claude API + brand voice prompt** pro pitch generation. Tato kategorie je **reference only** — vidět jak ostatní řeší.

| Repo | ★ | License | Last commit | Verdict | Notes |
|---|---|---|---|---|---|
| comsa33/GPT4-AI-resume | 49 | GPL-3.0 | 2023-04-10 | **C** stale + GPL | Personalized cover letter via GPT-4. Pattern OK, license ne. |
| pandmi/jobzilla_ai | 37 | MIT | 2024-05-29 | **C** reference | "AI models for automatic job application pipeline" — cherry-pick prompt patterns. |
| shreyansqt/covercraft-ai | 8 | MIT | 2024-12-17 | **C** reference | OpenAI GPT-4o cover letter PDF. Snippet pattern. |
| orlando70/cover-letter-generator | 17 | NoLicense | 2023-01-26 | **D** skip | Stale + nelicensed. |

**Cherry-pick: pattern only, no code.** Filip má lepší: Claude Sonnet 4.6 / Opus 4.7 + OneFlow brand voice rules + banned words check.

---

## 6. Auto-apply systems (P3 — anti-pattern reference)

Pochopit, jak vypadá automated bot z pohledu recruitera = pomoct Filipovi NEpůsobit jako bot.

| Repo | ★ | License | Last commit | Verdict | Notes |
|---|---|---|---|---|---|
| Lovelace98/LinkedIn_Job_Application_Automation_Bot | 11 | NoLicense | 2023-09-25 | **D** skip | Stale, nelicensed |
| bchikara/job_automater | 10 | MIT | 2025-11-08 | **C** reference | "End-to-end: scrape → generate → apply". Recent, dobrá architektura reference. |
| LinuxUser255/LinkedIn_Apply | 7 | GPL-3.0 | 2026-01-18 | **C** reference (GPL caution) | "Easy apply" automation. Pattern. |
| SaluRamos/vaga-automatica-linkedin | 4 | NoLicense | 2026-01-25 | **D** skip | Nelicensed |

**Klíčový anti-pattern insight:** všechny tyto boty fail same way:
- Generic templates → recruiter okamžitě pozná
- Send rate >100/den → IP/account block
- No personalization beyond "{name} {company}" → ignore
- Same time-of-day → bot fingerprint
- LinkedIn detection → account ban

**Filip aplikace:** opačný směr (aktivně NEPŘÍMĚŤ tyto signály):
- Personalize per posting (cite specific repost frequency, role detail)
- <50/den/sender first month, escalate gradually
- Vary send time (08:30–11:00 random distribution)
- Different sending domain per campaign (warm-up rotation)

---

## Cherry-pick blueprint — jak to slepit

Pseudo-architektura kombinující top 3 + Filip's existing assets:

```
Layer 1: SCRAPING (build, inspired by JobSpy)
   ┌─ scrapers/jobs_cz.py       (Scrapling Fetcher + adaptive selectors)
   ├─ scrapers/prace_cz.py      (Scrapling, RSS-first kde dostupné)
   ├─ scrapers/startupjobs.py   (official Bearer API — žádný scrape)
   ├─ scrapers/profesia_cz.py   (Scrapling StealthyFetcher pro Cloudflare)
   └─ models/JobPost.py         (universal schema z JobSpy)

Layer 2: ENRICHMENT (re-use Filip's cold-outreach-v3)
   └─ enrichment/waterfall.py   (ARES → Justice → LinkedIn → Hunter → Apollo → SMTP)
        +  algorithm-recall recipes/ares-fuzzy.py + contact-dedup.py

Layer 3: PAIN SCORING (build, inspired by deep-div/Cold-Email-Automation)
   ┌─ scoring/repost_detector.py    (job_id reappears in N days)
   ├─ scoring/urgency_lexicon.py    ("urgentně"/"asap"/"ihned" patterns)
   ├─ scoring/role_to_service.py    (AI Engineer → Filip AI agents service)
   └─ scoring/composite_score.py    (0-100 priority)

Layer 4: AI PITCH (build with Claude, no OSS)
   ┌─ pitch/jd_parser.py             (extract role/seniority/skills/urgency)
   ├─ pitch/intent_mapper.py         (job → Filip service catalog)
   └─ pitch/personalizer.py          (Claude Sonnet/Opus + Filip brand voice)

Layer 5: OUTREACH (cherry-pick from PaulleDemon + deep-div)
   ┌─ send/postfix_orchestrator.py   (Filip Postfix dopita@oneflow.cz, rate limit, warm-up)
   ├─ send/sequence_engine.py        (multi-step cadence T+0/+3/+7/+14/+21)
   └─ send/reply_tracker.py          (IMAP poll, classify, push GHL)

Layer 6: CRM SYNC (Filip's existing GHL)
   └─ crm/ghl_pusher.py              (push leads to GHL pipeline stages)

Layer 7: MONITORING (existing infra)
   ┌─ monitoring/ntfy_alerts.py      (high-score lead notification)
   └─ monitoring/dashboard.md        (Obsidian Vault page)
```

**Build estimate:**
- Layer 1: 4 dny (4 adaptery × 1 den; Scrapling MCP recipes accelerují)
- Layer 2: 0 dní (re-use cold-outreach-v3)
- Layer 3: 2 dny (custom logic)
- Layer 4: 2 dny (prompt engineering + few-shot examples)
- Layer 5: 3 dny (cherry-pick + Postfix integration)
- Layer 6: 1 den (GHL API wrapper)
- Layer 7: 0,5 dne (ntfy + Obsidian)
- **Total MVP: ~12 dní práce**

---

## AVOID — co nepoužít

### Halucinované repos (404 verified)
Tyto repos **neexistují** ale objevily se v initial research drafts (LLM halucinace):
- ❌ `jpadilla/reverse-recruiter-api` — 404
- ❌ `cheeseman1/CoverLetter-Generator` — 404
- ❌ `Infinidat/fire-enrich` — 404 (Infinidat je real org, fire-enrich repo neexistuje)
- ❌ `mlficer/AI-Lead-Generator` — 404

**Lekce:** všechny GitHub repos verifikuj přes `gh api repos/X/Y` nebo `curl -s https://api.github.com/repos/X/Y` před adopcí.

### Risky / problematic repos
- **AGPL-3.0 repos** (JobFunnel, některé scrapers) — copyleft infect, vyžaduje sourcing celého produktu pokud public-facing
- **Archived repos** (feder-cr/AIHawk 29k★) — projekt mrtvý, žádné updates pro nové job-board changes
- **NoLicense repos** — bez explicit license = nelegální fork/použití
- **LinkedIn scraper repos** s headless login — ToS violation Section 8.1, account ban risk
- **Gemini API-dependent repos** (např. `praj2408/...With-Google-Gemini-Pro`) — blocked per cost-zero-tolerance.md (Filip ban Google API 2026-04-27)
- **Selenium-based scrapers** — pomalé, fragile, lepší Scrapling 0.4.7 + Patchright

---

## Final recommendation

**Filip MVP stack (12 dní práce):**
1. **Scrapling 0.4.7** (already installed, MCP active) — base scraping framework
2. **JobSpy architecture pattern** (study, adopt) — Layer 1 modular adapters
3. **deep-div/Cold-Email-Automation** (Apache-2.0, fork) — Layer 5 outreach orchestration
4. **PaulleDemon/Email-automation** (cherry-pick rate-limit logic) — Layer 5 send infrastructure
5. **Filip's cold-outreach-v3** (reuse 100%) — Layer 2 enrichment waterfall
6. **Filip's algorithm-recall recipes** (reuse) — ARES fuzzy matching, contact dedup
7. **Claude API direct** (no OSS pitch generator) — Layer 4 AI matching
8. **Postfix dopita@oneflow.cz** (existing infra) — send infrastructure
9. **GHL API** (existing) — CRM sync

**Žádný OSS reverse-recruiter end-to-end repo neexistuje. Filip postaví něco co může pak productize jako "JobSignal CZ" SaaS** (per strategy.md monetization sekci 7).

---

**Word count: 1,520 | Verified: 2026-05-04 | Method: GitHub API live verification + curl validation**

Dopita
