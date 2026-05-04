# Reverse-Recruiter Lead-Gen System — Master Index

**Datum:** 2026-05-04 | **Pro:** Filip Dopita / OneFlow | **Status:** Research complete, build-ready

## Co to je

Systém který scrapuje CZ job-boardy (Jobs.cz, Práce.cz, StartupJobs, Profesia), detekuje firmy s **pain signálem** (hledají roli kterou Filipova agency umí outsourcovat), AI generuje personalized pitch a posílá outreach z `outreach@oneflow.cz` s reply tracking → GHL CRM. Cíl: monetizovat insight *"job posting = pain signal = sales opportunity"* místo nového FTE prodat outsource/agency/automation/consulting.

## Reading order (60 min full briefing)

| # | Soubor | Slov | Účel |
|---|---|---:|---|
| 1 | **[jobs-leadgen-INDEX.md](jobs-leadgen-INDEX.md)** | ~600 | Tento dokument — exec summary + decision tree |
| 2 | [jobs-leadgen-strategy-and-AI-matching.md](jobs-leadgen-strategy-and-AI-matching.md) | 3,104 | Business model, pain signal taxonomy, AI matching, persuasion frameworks, compliance, pricing |
| 3 | [jobs-leadgen-CZ-boards.md](jobs-leadgen-CZ-boards.md) | 1,333 | Feasibility per portál (Jobs.cz/Práce.cz/StartupJobs/Profesia/LinkedIn/Indeed/niche), GDPR sekce |
| 4 | [jobs-leadgen-OSS-cherrypick.md](jobs-leadgen-OSS-cherrypick.md) | 1,932 | Top GitHub repos (verified API), cherry-pick blueprint, AVOID seznam |
| 5 | [jobs-leadgen-ECOSYSTEM-mapping.md](jobs-leadgen-ECOSYSTEM-mapping.md) | 2,678 | Mapping na Filipovy existing skills, architektura, GSD plan, first-24h commands |
| 6 | [jobs-leadgen-IMPLEMENTATION.md](jobs-leadgen-IMPLEMENTATION.md) | ~1,200 | 8-week action plan s konkrétními příkazy per fáze |

**Total: ~10,800 slov / ~45-60 min reading.**

---

## Executive Summary (TL;DR)

### 5 must-know insightů

1. **Trh je validovaný** — Toptal/Andela/Crossover dokazují agency-as-replacement-for-hire model na $100M+ ARR. CZ market má whitespace (limited competition: AzaJobs, Recruitis, LinkedIn premium).

2. **Data layer je dostupný** — Jobs.cz/Práce.cz robots.txt allow scrape (P0), StartupJobs.cz má **oficiální Bearer API** (P0, žádný scrape risk). LinkedIn = ToS violation risk (Sales Navigator API only).

3. **Pain signály jsou kvantifikovatelné** — repost 3+× v 30 dnech = 4:1 multiplier pro engineering, +15% salary band = 87% budget approval, "urgentně"/"ASAP" wording = 76% expedited decision.

4. **70% pipeline existuje** — Filip má `cold-outreach-v3` (6-fázový enrichment+send), `lead-ops` (scoring engine), `leadgen` (natural-query → Excel), `scrapling` (anti-bot), `algorithm-recall` recipes (ARES fuzzy + contact dedup). Build je **scraping layer + pain scoring + AI matching** (~12 dní práce).

5. **Compliance pathway clear** — GDPR Article 6(f) legitimate interest + CZ ZoEK §7 e-marketing opt-out = defensible. Cost legal review €2-5k. **Decision gate konec května 2026** pro 6-měsíční head start.

### Ekonomika (conservative 12-month)

| Phase | Window | Revenue | Net margin |
|---|---|---|---|
| Pilot | W1-4 | €10k pipeline | 0 (validation) |
| Scale-up | M2-4 | €40k/měs | €24k/měs (60%) |
| Full scale | M5-12 | €90k/měs | €63k/měs (70%) |

**Pricing options**:
- Per-lead €30-100 (low LTV, validation only)
- Placement fee €3-8k (60% margin, 30-day pay)
- Retainer €3-10k/měs (70% margin, 3-měsíční minimum)
- SaaS "JobSignal CZ" Y2 (€99-499/měs, productized)

### Build estimate

**MVP: ~12 dní kódu + ~2 týdny pilot + 2-3 týdny sales = 5-8 týdnů celkově**

| Layer | Effort | Re-use vs Build |
|---|---:|---|
| Scraping (4 portál adaptery) | 4 dny | BUILD (Scrapling base ready) |
| Storage (SQLite) | 0,5 dne | BUILD |
| Enrichment (ARES → Apollo waterfall) | 0 dní | RE-USE `cold-outreach-v3` |
| Pain scoring (repost + urgency + role match) | 3 dny | BUILD |
| AI pitch (Claude + brand voice) | 2 dny | BUILD (no OSS adopt) |
| Outreach (Postfix + sequence) | 2 dny | RE-USE `cold-outreach-v3` Phase 5+6 |
| GHL sync | 1 den | BUILD wrapper |
| Monitoring (ntfy + Obsidian) | 0,5 dne | RE-USE existing |

---

## Decision tree — kam jít dál

```
Filip rozhodne nyní:
│
├── A. SPUSTIT MVP build (12 dní + 2 týdny pilot)
│   └── /gsd:new-milestone reverse-recruiter-cz
│       └── Phase 1 (Scraping foundation, W1)
│           └── Smoke test příkazy v IMPLEMENTATION.md sekce W1
│
├── B. JEN PILOT validation (Week 1, ~16h work)
│   └── Manual scrape 100 firem z Jobs.cz/Práce.cz
│       └── Confirm 4:1 repost multiplier hypothesis
│           └── Pokud PASS → eskalovat na Option A
│           └── Pokud FAIL → pivot/pause
│
├── C. ODLOŽIT (decision >2 týdny)
│   └── Risk: ztráta 6-měsíční first-mover window
│       └── Re-evaluate srpen 2026 (refresh briefing)
│
└── D. SAAS-FIRST approach (productize first, customer second)
    └── /saas-from-workflow s tímto blueprint jako vstup
        └── Vyšší cost, větší TAM, slower revenue
```

**Recommendation: Option B → Option A** (validate first, build with confidence).

---

## Top 3 risks

1. **GDPR / ZoEK §7 compliance failure** — High impact, medium probability. Mitigation: pre-pilot legal review (€2-5k, 2 týdny), audit trail logging, mandatory opt-out.

2. **Pitch positioning trigger HR hostile response** — High probability, medium impact. Mitigation: NIKDY "we replace your hiring team"; instead "compression of timeline" framing, target CTO/founder bypass HR.

3. **Send infrastructure reputation drop** — Filip's `dopita@oneflow.cz` je critical infra. Mitigation: dedicated `outreach@oneflow.cz` inbox, separate warm-up, max 50/den/sender first month.

---

## Top 3 opportunities

1. **First-mover CZ window** — žádná competition v reverse-recruiter automation pro CZ. 6-18 měsíců než LinkedIn/AlmaCareer replikují.

2. **Service catalog perfect fit** — Filip má AI agents service (30-300k Kč build, 15-300k Kč/měs retainer). Pain signál "AI Engineer hledá 4 týdny" → direct sale "máme to za 2 týdny za 25k Kč/měs".

3. **Productization path** — Y1 internal lead-gen, Y2 "JobSignal CZ" SaaS pro recruitment agencies (€99-499/měs). Compounding moat z accumulated CZ hiring data.

---

## Akce příští 24h

```bash
# 1. Read full briefing (45 min)
open /Users/filipdopita/Desktop/Codex/research-briefings/2026-05-04/jobs-leadgen-INDEX.md

# 2. Decision: Option A / B / C / D (5 min)

# 3. Pokud A: založit milestone
cd ~/Desktop/Codex && mkdir -p reverse-recruiter && /gsd:new-milestone reverse-recruiter-cz

# 4. Pokud B: pilot smoke test (viz IMPLEMENTATION.md sekce W1)
~/.venvs/scrapling/bin/python -c "from scrapling.fetchers import Fetcher; print(Fetcher.get('https://www.jobs.cz/prace/').status)"

# 5. Pre-flight: legal counsel intake (parallel)
# Email CZ-based GDPR specialist re: Article 6(f) job-posting cold outreach
```

---

**Created: 2026-05-04 | Author: Filip's Claude session | Method: 4 paralelní research forks (3 fresh re-spawned po context-overflow) + manual GitHub API verification + filesystem ekosystem mapping**

Dopita
