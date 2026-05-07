# ai-radar v4 — Maximum Effectivity Upgrade Spec

**Date:** 2026-05-07
**Author:** Claude Code (Filip's Opus 4.7) → delegate Codex
**Mandate:** Filip 2026-05-07 — *"vylepši mi skill ai-radar, dotáhni na maximální možnou úroveň efektivity a funkčnosti pro mě, mé projekty, ekosystém, bezpečnost a schopnost tvořit, být kreativní a samostatný"*
**Target path:** `~/.claude/skills/ai-radar/`
**Replaces:** v3.0 (2026-05-03) + Wave 5 closure (2026-05-06)

---

## Filozofie upgrade

v3 byl tool radar (12 AI sources). v4 je **Filip's life radar**: scans 5 dimenzí života Filipa zároveň — AI tooling + active projects + ekosystem health + security + creative inspiration. Default output má **3 next actions na první řádek**, ne TL;DR.

## Současný stav (verified 2026-05-07)

- 11 scripts, 3258 řádků total
- 12 external sources + 8 internal dims + 6 action types
- Composite 100/100 sustained 11+ runs (od Wave 5 closure)
- 98 decisions logged
- Last full external scan: 2026-05-05 (700KB audit JSON)
- Daily-lite cron Mon-Sun 03:35 (composite check + ntfy alert)
- 5 .bak files akumulované v `~/.claude/ai-radar/`

## Identifikované gaps (proč v4)

| Filip's mandate | Současný stav | Gap |
|---|---|---|
| **efektivita** | 60-150s full run, no cache | Same-day cache miss → re-fetch full external každý run |
| **funkčnost** | 12 AI sources, 8 internal dim | Žádná adjacent doména pokrytí |
| **projekty** | Skenuje `~/.claude/` blindly | 30+ active projects (jobs.cz, distressed-leads, gws, Tereza ops) — radar je nezná, žádný relevance boost |
| **ekosystém** | services/skills/hooks/MCPs/router | Chybí: Obsidian vault drift, Codex bridge utilization, Hermes/KARIMO health, scheduled task drift |
| **bezpečnost** | Jen internal credentials expiry | Chybí: CVE feed (NVD), GHSA pro Filip's stack tools, SSL cert expiry pro 9 oneflow domains, sister domain DNS drift |
| **kreativita** | NULL | Filip = content creator + brand owner. Chybí entirely |
| **samostatnost** | AUTO=5/run, REVIEW_QUEUE pasivní | Chybí: trajectory regression alerts, "next 3 actions" hned na vrchu reportu, auto-process REVIEW_QUEUE když >5 items |

## v4 architektura — 7 nových capabilit

### 1. **Creative dimension** (NEW external focus)
**File:** `scripts/scan-creative.sh` (~120 LOC)
**Triggered by:** `--focus=creative` nebo default scope=all
**Sources (free, žádné API klíče):**
- `gh api repos/Lykon/awesome-stable-diffusion/commits` — community model registry
- `https://api.fal.ai/health` + `gh api repos/fal-ai/fal/releases` — fal.ai model release diffs
- `https://www.runwayml.com/product/changelog` (RSS-like fetch)
- `https://github.com/topics/social-media-automation` (trending repos last 7d)
- `https://github.com/topics/content-creation-ai` (trending)
- `gh api repos/openai/sora/releases` (when public)
- Awesome lists: `awesome-creative-coding`, `awesome-stable-diffusion-prompts`, `awesome-content-creation`
- Filtruj: keywords `IG | Instagram | TikTok | Reels | viral | hook | carousel | thumbnail | content | brand | creative | video AI | image gen | seedance | Krea | Recraft | Runway`

**Score boost:** Creative findings dostávají `+2 source_quality_boost` jen pokud match na Filip's content stack v `~/.claude/expertise/oneflow-brand.yaml` keywords.

### 2. **Project-aware relevance scoring** (v audit-engine.py modifier)
**New file:** `scripts/project-context.py` (~80 LOC)
**Logic:**
1. Skenuje:
   - `ls -lt ~/Desktop/Codex/HANDOFF-*.md | head -10` → extract project names + last-touch date
   - `ls -lt ~/.claude/projects/*/memory/project_*.md | head -20` → extract project tags
   - `git -C ~/Desktop/Codex log --since="14 days ago" --name-only` → modified file roots
2. Output: JSON `{"active_projects": [{"name": "jobs-cz-system", "last_touch": "2026-05-05", "keywords": ["jobs.cz", "ICP", "ARES", "Apify"]}]}`
3. Cache do `~/.claude/ai-radar/cache/project-context.json` (refresh 1×/24h)

**Modifier integration v audit-engine.py:**
- Existing scoring: 4-dim Fit/Novelty/Effort/Impact (max 45) + source_boost + learning_boost
- New: `project_relevance_boost = +5` pokud finding.title nebo finding.description match na ANY active_project keyword
- New: `project_decay_penalty = -3` pokud finding match na inactive project (touched >60d) — signal že je outdated tool

### 3. **Security CVE + advisories feed** (NEW internal dim)
**File:** `scripts/security-feeds.sh` (~150 LOC)
**Output dim:** `security` (composite 0-100, příspěvek do internal score)
**Sources:**
- NVD JSON 2.0 API: `curl 'https://services.nvd.nist.gov/rest/json/cves/2.0?lastModStartDate=...&lastModEndDate=...'` (no auth, 5 req/30s rate limit)
- GHSA: `gh api /advisories?ecosystem=pip&affects=apify-client,scrapling,playwright,bun,httpx,curl-cffi`
- Tools v scope: `scrapling, playwright, bun, postfix, dovecot, nginx, openssh, curl-cffi, httpx, openssl, kuzudb, kalman, hermes-agent, karimo, sqlite, gemini-cli (DISABLED), opencode, anthropic-sdk-python, fastmcp`
- SSL cert expiry: `openssl s_client -connect $domain:443 -servername $domain </dev/null 2>/dev/null | openssl x509 -noout -dates` pro 9 oneflow domains (oneflow.cz, oneflow-team.cz, joinoneflow.cz, helponeflow.cz, help-oneflow.cz, ai-asociace.cz, asociaceaivedy.cz, zaregistrujeme.cz, dluhopisy.cz)
- Sister DMARC drift: parse `~/.claude/logs/dmarc-history.log` last 7d (if exists)

**Scoring:**
- composite 100 = 0 CVEs critical/high, all certs >30d valid, all DMARC PASS
- -10 per critical CVE matching tool
- -5 per high CVE
- -20 per cert expiring <14d
- -15 per DMARC FAIL >5%

### 4. **Action plan v TL;DR header** (modifies unified-router.sh)
**Change:** Run report frontmatter získá pole `next_actions` array (top 3).
**Format v report:**
```markdown
# AI Radar — 2026-05-07

## ⚡ Top 3 next actions
1. **[REVIEW_QUEUE]** `bridge-mind/BridgeWard` (score 35) — prompt injection defense pro cold-email pipeline. Run: `/apply-improvements bridge-mind`
2. **[SECURITY]** Cert `oneflow.cz` expires in 12 days — Renew Let's Encrypt: `ssh root@10.77.0.1 certbot renew`
3. **[CREATIVE]** Nová Krea v3 model release — Filip uses Krea v ad-creative skill. Test: `/image-prompt "<test>"` s `model=krea-v3`

## TL;DR
[existing TL;DR content]
```

**Logic v unified-router.sh:**
1. Aggregate top finding z REVIEW_QUEUE (max score) + top SECURITY warning + top CREATIVE finding pokud existuje
2. Format jako 1-line per action s konkrétním command pro Filipa (zero ambiguity)
3. Append do `~/.claude/ai-radar/runs/<date>.md` HEADER position (před TL;DR)

### 5. **Same-day cache layer** (efektivita)
**File:** `scripts/scan.sh` modify — add `CACHE_TTL_MINUTES=720` (12h)
**Logic:**
- `fetch_with_cache()` already exists ale TTL nezná. Add: pokud cache file `<24h staré` → hit, ne re-fetch
- Per-source TTL override: Anthropic releases = 1h (vyšší recence), Awesome lists = 24h, OpenRouter free = 6h
- Output: log "[ai-radar] cache HIT: anthropic-cookbook (12 items, age 4h)" do stderr

**Expected savings:** 2nd run same day: 60-150s → 5-15s (90% redukce)

### 6. **--explain mode** (transparency + samostatnost)
**File:** new `scripts/explain.sh` (~50 LOC) + SKILL.md update
**Trigger:** `/ai-radar --explain <finding-id>`
**Output:**
```
Finding: bridge-mind/BridgeWard (id: ext-2026-05-06-bridge-mind)

## Score breakdown
- Fit: 12/15 (matches OneFlow cold-email pipeline keyword "prompt injection")
- Novelty: 8/10 (created 2026-04-28, low star count = early signal)
- Effort: 6/10 (Tier 1 alternative to manual prompt review)
- Impact: 9/10 (cold-email reply parsing has injection risk)
- Source boost: +2 (BridgeWard org curated)
- Project boost: +5 (matches active "cold-outreach-v3" project)
- Learning boost: +0 (no historical Filip decisions on prompt injection)
- TOTAL: 42/45

## Cross-ref category
NEW_MCP_AVAILABLE — Filip stack covers cold-email but no defense layer

## Bayesian falsification
"Why might this be wrong?"
- BridgeWard might be too new (20 stars) — could be hype, not battle-tested
- Risk: skill addition adds prompt complexity, may slow cold-email path
- Mitigation: Tier 1 "evaluate-only" mode bez writes

## Routing decision
Score 42 >= 38 (CREATE_REFERENCE_MEMORY threshold), confidence VERIFIED
→ AUTO_IMPLEMENT: CREATE_REFERENCE_MEMORY
→ Created: ~/.claude/projects/.../memory/reference_bridge_mind_2026_05_06.md

## Filip next steps
1. Read reference memory file
2. Decide: integrate now / watchlist / skip
3. If integrate: chain s `cold-outreach-v3` skill in workflow-routing.md
```

**Storage:** `--explain` reads `~/.claude/ai-radar/runs/audit-<date>.json` + decisions.jsonl, formats human-readable.

### 7. **Hygiene + path consistency** (anti-hallucination + samostatnost)
**Changes:**
- **SKILL.md path fix:** Replace `memory/reference_tool_watchlist.md` → `~/.claude/ai-radar/watchlist.md` (5 occurrences)
- **Auto-cleanup .bak >7 days:** Add to `prune-watchlist.sh` end of file: `find ~/.claude/ai-radar -name "*.bak.*" -mtime +7 -delete -print`
- **Rotate decisions.jsonl >5000 lines:** Wire `rotate-decisions.sh` into `unified-router.sh` end-of-run check (`wc -l decisions.jsonl > 5000 && bash rotate-decisions.sh`)
- **Sync OneFlow-Vault watchlist:** Symlink `~/Documents/OneFlow-Vault/09-Agent-Memory/reference_tool_watchlist (sync).md` → `~/.claude/ai-radar/watchlist.md` OR delete the orphans (Filip preference: delete orphans, single source of truth)
- **Smoke test runner:** Add `scripts/smoke-test.sh` — runs all 11+3 scripts in --dry mode, reports PASS/FAIL per script. Run weekly via launchd.

## Detailní implementační plán (10 kroků pro Codex)

### Phase 1 — Foundation (no risk)
1. **Path fix v SKILL.md** — sed s/memory\/reference_tool_watchlist.md/~\/.claude\/ai-radar\/watchlist.md/g (verify 5 occurrences)
2. **`prune-watchlist.sh` extend** — append .bak cleanup (mtime >7 dní)
3. **`unified-router.sh` end-of-run hook** — add `wc -l ~/.claude/ai-radar/decisions.jsonl` check + rotate trigger

### Phase 2 — Cache + efficiency (low risk)
4. **`scan.sh` cache TTL upgrade** — `fetch_with_cache()` honor 12h default + per-source overrides
5. **Smoke test** — verify 2nd run same day = <15s

### Phase 3 — Project awareness (medium risk)
6. **Create `scripts/project-context.py`** — extract active projects from HANDOFF-*.md + memory
7. **Modify `audit-engine.py`** — load project-context.json, apply +5 project_relevance_boost in scoring loop
8. **Update SKILL.md architecture diagram** — add Project Context layer

### Phase 4 — New dimensions (medium risk)
9. **Create `scripts/scan-creative.sh`** — 8 creative sources, parallel fetch
10. **Create `scripts/security-feeds.sh`** — NVD + GHSA + cert + DMARC, output `security` dim
11. **Modify `scan-internal.sh`** — add `dim_security` parallel branch
12. **Modify `unified-router.sh`** — aggregate creative + security findings, top 3 next_actions header

### Phase 5 — Transparency + autonomy (low risk)
13. **Create `scripts/explain.sh`** — read audit JSON + decisions, format human report
14. **Modify `SKILL.md`** — add `--explain` to argument-hint, document in commands table
15. **Create `scripts/smoke-test.sh`** — runs all scripts --dry, weekly launchd

### Phase 6 — Validation
16. **End-to-end test:** `/ai-radar --scope=all --focus=creative --days=7` — expect creative findings + project-aware boost + security dim populated
17. **Verify v3 backwards compat** — existing `--scope=internal --lite` cron still works
18. **Update SKILL.md verzování** — F-200..F-220 = v4 iteration tags

## Acceptance criteria

- [ ] All 11 phases done
- [ ] Smoke test 14/14 PASS
- [ ] 2nd same-day run <15s (cache hit)
- [ ] `--scope=all` produces report s ≥1 creative finding (assuming creative source has any 7d activity)
- [ ] `--scope=internal` security dim populated (at minimum cert expiry checks)
- [ ] Top 3 next_actions appear in run report header
- [ ] `--explain <id>` works on a recent finding from decisions.jsonl
- [ ] `prune-watchlist.sh` after run = .bak count <5 files
- [ ] composite score still 100/100 nebo close (žádná regresní degradace)
- [ ] decisions.jsonl unbroken (single-line JSON, valid)
- [ ] SKILL.md updated to v4.0 + version table at bottom

## Hard constraints (NIKDY)

- Žádná Google API (cost-zero per `~/.claude/rules/cost-zero-tolerance.md`)
- Žádná modifikace `~/.claude/CLAUDE.md` ani aktivních rules mid-session
- Žádné secrets v hardcoded form (use `~/.credentials/master.env`)
- Žádné odeslání emailu / zprávy
- AUTO_IMPLEMENT max 5 items/run (existing constraint zachovat)
- Žádný npm/pip/brew install — všechny nové dependencies = stdlib (Python 3.11+) nebo bash + curl/jq/gh
- Backup PŘED modifikací: každý existing script → `<script>.bak.v3` PŘED první edit

## Rollback path

```bash
# Full rollback to v3 (Wave 5 baseline)
cd ~/.claude/skills/ai-radar
for f in *.bak.v3; do mv "$f" "${f%.bak.v3}"; done
git -C ~/.claude/ checkout HEAD~1 skills/ai-radar/SKILL.md
```

## Estimated scope

- **New files:** 5 (scan-creative.sh, security-feeds.sh, project-context.py, explain.sh, smoke-test.sh)
- **Modified files:** 6 (SKILL.md, scan.sh, scan-internal.sh, audit-engine.py, unified-router.sh, prune-watchlist.sh)
- **Total LOC:** ~600 new + ~150 modified
- **Time:** 60-90 min Codex implementation + 15 min Filip verification
- **Cost:** 0 Kč (no paid APIs, OpenRouter free already in stack)

## Reference dokumenty

- Current SKILL.md: `~/.claude/skills/ai-radar/SKILL.md`
- v3 architecture: section "Architektura (5 vrstev)"
- 1000% closure history:
  - `~/.claude/projects/-Users-filipdopita-Desktop-Codex/memory/project_ai_radar_2026_05_06_1000pct.md`
  - `~/.claude/projects/-Users-filipdopita-Desktop-Codex/memory/project_ai_radar_2026_05_05_1000pct.md`
  - `~/.claude/projects/-Users-filipdopita-Desktop-Codex/memory/project_ai_radar_run_2026_05_03_closure.md`
- Decisions log: `~/.claude/ai-radar/decisions.jsonl` (98 entries)
- Active projects scan: `ls -t ~/Desktop/Codex/HANDOFF-*.md | head -10`

---

**Sign-off:** Tento spec je self-contained pro Codex implementaci. Po dokončení Codex updatuje memory entry `project_ai_radar_v4_upgrade_2026_05_07.md` s acceptance criteria PASS/FAIL grid + commit hash.
