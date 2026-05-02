# Wave 2 Pickup V2 — Finální dotahnutí (W3, W5, W7, W8)

**Vytvořeno:** 2026-05-02 23:42 CEST (post-W2+W6)
**Předchozí stav:** W1+W2+W4+W6 done. Zbývá W3+W5+W7+W8. ~9-13h celkem.
**Master plán:** [`SESSION-WAVE2-100PCT.md`](SESSION-WAVE2-100PCT.md)
**Předchozí pickup:** [`SESSION-WAVE2-PICKUP.md`](SESSION-WAVE2-PICKUP.md) — pre-W2 baseline

---

## 0. PRE-FLIGHT (povinné na začátku každé session)

```bash
cd ~/Desktop/Codex
echo "=== PICKUP V2 SNAPSHOT $(date -Iseconds) ==="
find ~/.claude/skills/ -maxdepth 1 -mindepth 1 -not -name "_*" | wc -l   # cíl: 289 (post-W2 baseline)
find ~/.claude/skills/ -maxdepth 1 -mindepth 1 -name "gsd-*" -not -name "_*" | wc -l  # cíl: 56 (post-W2)
find ~/.claude/hooks/ -maxdepth 1 -type f \( -name "*.sh" -o -name "*.js" -o -name "*.py" \) | wc -l  # cíl: 43
python3 -c "import json; cfg=json.load(open('/Users/filipdopita/.claude/settings.json')); print('MCPs:', len(cfg['mcpServers']))"  # cíl: 14
git -C ~/Desktop/Codex log --oneline -5
```

**Acceptance:** snapshot match (skills 289, GSD 56, MCPs 14). Pokud ne → drift, čti `~/.claude/projects/-Users-filipdopita-Desktop-Codex/memory/project_w2_completion_2026_05_02.md`.

### Re-read klíčových rules (1× za session)
```bash
head -50 ~/.claude/CLAUDE.md
head -100 ~/.claude/rules/completion-mandate.md
head -80 ~/.claude/rules/anti-hallucination.md
```

### Pre-W3/W5 backup (destruktivní waves)
```bash
TS=$(date +%Y%m%d_%H%M%S)
mkdir -p ~/Documents/backups
tar -czf ~/Documents/backups/claude-skills-w3-${TS}.tgz -C ~/.claude skills
cp ~/.claude/settings.json ~/.claude/settings.json.bak.${TS}
cd ~/.claude/projects
tar -czf ~/Documents/backups/claude-memory-old-${TS}.tgz "./-Users-filipdopita"
```

---

## Verified baseline post-W2+W6 (anti-halluci)

| Fact | Value | Source |
|------|-------|--------|
| Skills active | 289 (W2 -16) | `find ... -not -name "_*"` |
| GSD active skills | 56 (W2 -17) | `find ... -name "gsd-*"` |
| GSD agents | 31 (untouched, conservative path) | `find ~/.claude/agents/ -name "gsd-*.md"` |
| Hooks executable | 43 (no W6 changes) | `find ~/.claude/hooks/` |
| MCPs | 14 (W6 +2: context7, time) | settings.json |
| Strict orphans | 160 / 289 (cross-checked rules+hooks+agents+skills) | `~/.claude/audits/2026-05-02-W7-orphan-skills.txt` |
| Memory entries (Codex project) | 8 | `ls ~/.claude/projects/-Users-filipdopita-Desktop-Codex/memory/` |
| W2 archived | 22 skills + 1 agent.bak | `~/.claude/skills/_archived_2026_05_02_wave2/W2/` |

### W6 MCPs added
- **context7** (@upstash/context7-mcp@2.2.3) — anti-halluci, real-time lib docs (`mcp__context7__query-docs`, `resolve-library-id`)
- **time** (time-mcp@1.0.6) — LLM time awareness, scheduling math
- Backup: `~/.claude/settings.json.bak.20260502_233946`
- Restart Claude Code session (`/clear` → restart) pro MCP loading

### W2 umbrella commands shipped (9)
- `/gsd-debug --forensics` (folded gsd-forensics)
- `/gsd-stats --health|--scan` (folded 2)
- `/gsd-audit --fix|--milestone|--uat|--eval|--validate` (folded 5)
- `/gsd-todo --add|--check|--note` (folded 3)
- `/gsd-workspace --list|--new|--remove` (folded 3)
- `/gsd-phase --add|--insert|--remove` (folded 3)
- `/gsd-work --pause|--resume` (folded 2)
- `/gsd-config --settings|--profile` (folded 2)
- `/gsd-import --from-gsd2` (folded 1)

Migration table: `~/.claude/get-shit-done/workflows/help.md` (end-of-file).

---

## Anthropic SDK Decision (W6 documented)

**Verified 2026-05-02:** Latest Python SDK = `0.97.0` (released 2026-04-23). Plan claim "0.97" was correct.

**Decision:** UPGRADE postponed to W7 active session. Reasoning:
- No active OneFlow Python project currently uses Anthropic SDK at risk
- Verify pinning in `~/Documents/oneflow-claude-project/` before upgrade (potential breaking changes)
- Best done in dedicated W7 session, not bundled with skill ops

**Action item for W7:** `pip show anthropic` v každém aktivním projektu, decision per-project.

**Trail of Bits skills:** SKIP for now — adds complexity without immediate ROI. Re-evaluate if security-toolkit needs strengthening.

---

## Optimal session split (zbývající 4 sessions)

| Session | Waves | Time | Risk | Strategy |
|---------|-------|------|------|----------|
| **3** | W3 (oversized refactor) | 4-6h | MEDIUM-HIGH | 1 wave per session, 5 sub-tasks (graphify/last30days/mythos/writing/ai-radar) |
| **4** | W5 (memory orphans) | 2-3h | LOW-MEDIUM | Bulk auto-categorize → archive |
| **5** | W7 (orphan skills triage) | 3-4h | LOW-MEDIUM | Use orphan list, batch wire/archive/merge |
| **6** | W8 (final commit + ntfy) | 30-45min | NONE | Synthesis + commit + memory |

**Dependency:** W3, W5, W7 nezávislé. W8 → konec.

---

## Wave 3 — Oversized refactor (4-6h, MEDIUM-HIGH risk)

### Targets verified bytes 2026-05-02
| Skill | Lines | Strategy | Action |
|-------|-------|----------|--------|
| graphify | 1313 | SPLIT 3-way | graphify-parse + graphify-query + graphify-viz |
| last30days | 881 | EXTRACT patterns | core dispatch + reference/<cat>/.md |
| mythos | 683 | COMPRESS | scenarios → memory pointer |
| writing-skills (662) + copywriting (252) | merge | MERGE → `writing` | dedupe voice/tone/structure |
| ai-radar | 659 | LAZY-LOAD | dispatcher + dimensions/<dim>.md |

### Per-skill strategy

**1. graphify (1313L) — split 3-way**
```bash
# Read full file first
wc -l ~/.claude/skills/graphify/SKILL.md
# Identify natural split points: parse logic, query logic, viz logic
# Create graphify-parse/, graphify-query/, graphify-viz/ dirs
# Move sections to each. Keep graphify/SKILL.md as router (--parse|--query|--viz)
# OR fully replace graphify with 3 separate skills
```

**2. last30days (881L) — extract patterns**
```bash
# Sections: news scrape, X/Twitter, Reddit, blog ranking, AI tools, content patterns
# Move each to reference/last30days/<category>.md
# Keep SKILL.md as dispatcher reading reference files on-demand
```

**3. mythos (683L) — compress**
```bash
# Sections: epistemology core, Bayesian markers, ACH, scenarios
# Move scenarios to ~/.claude/projects/-Users-filipdopita-Desktop-Codex/memory/reference_mythos_scenarios.md
# Keep core in SKILL.md (~300L target)
```

**4. writing-skills + copywriting → writing (merge)**
```bash
# Both touch voice/tone/structure
# Find dedupe points (Filip voice rules likely in both)
# Create writing/ umbrella with --skills (writing-skills logic) and --copy (copywriting logic)
# Archive originals
```

**5. ai-radar (659L) — lazy load**
```bash
# Sections: external scan, internal scan, cross-ref engine, 8 dimensions
# Move dimensions to ai-radar/dimensions/<dim>.md
# SKILL.md becomes dispatcher: --scope=external|internal|--full-effort|--lite
```

### Acceptance W3
- [ ] `find ~/.claude/skills/ -name SKILL.md -exec wc -l {} \; | sort -rn | head -5` → top 5 all <500L
- [ ] Smoke test: `head -30` of each modified SKILL.md (frontmatter valid, body present)
- [ ] Routing updated v knowledge-router.md (any per-dimension or per-mode entries)
- [ ] All originals → `_archived_2026_05_02_wave2/W3/`

### Anti-pattern z W2 lekce
- **NEARCHIVUJ** skill bez `wc -l` + `head -30` ověření (audit logic má bug — false positives)
- **NEZASTAVUJ** se na first iteration — Filipova "5x dotáhni" pattern, dělej úplně
- **POUŽIJ** Codex bridge pro file-heavy refactor (delegate split logic):
```bash
~/Desktop/Codex/ai-control-plane/scripts/delegate-to-codex.sh ~/.claude \
  "W3.1 graphify split — read ~/.claude/skills/graphify/SKILL.md (1313 lines), identify 3 split points (parse/query/viz), create 3 new SKILL.md files in graphify-parse/, graphify-query/, graphify-viz/, archive original do _archived_2026_05_02_wave2/W3/"
```

---

## Wave 5 — Memory orphans (2-3h, LOW-MEDIUM)

### Cíl
Old project memory: `~/.claude/projects/-Users-filipdopita/memory/` — 329 files, 172 listed → 157 orphans → **target <30**.

### Postup
1. Generate orphan list:
```bash
cd ~/.claude/projects/-Users-filipdopita/memory
ls *.md | grep -v "^MEMORY" > /tmp/all_memory_files.txt
wc -l /tmp/all_memory_files.txt
# Cross-ref MEMORY.md and MEMORY-INDEX-EXTRA.md
grep -oE '[a-z_0-9-]+\.md' MEMORY.md MEMORY-INDEX-EXTRA.md | sort -u > /tmp/listed.txt
comm -23 <(sort /tmp/all_memory_files.txt) /tmp/listed.txt > /tmp/orphans.txt
wc -l /tmp/orphans.txt
```

2. Auto-categorize by prefix (auto_, _pending, incident, feedback, knowledge, pm_, project, reference)

3. Apply rules per category:
| Category | Rule |
|----------|------|
| `auto_` | Bulk index in MEMORY-AUTO-INDEX.md (machine-generated entries) |
| `_pending` | Resolve or archive >7 days old |
| `incident_` | Keep critical, archive resolved >30 days |
| `feedback_` | All keep (Filip behavioral preferences = critical) |
| `knowledge_` | Move >30 days to `_archive/<rok>-<měsíc>/` if not referenced |
| `pm_` | Project mgmt scratch — archive >14 days |
| `project_` | Active projects only — archive completed >30 days |
| `reference_` | Bulk index in references section, archive >60 days |

4. Bulk archive PROJECT entries >30d → `_archive/2026-04/`

5. Re-count → target <30 orphans

### Acceptance W5
- [ ] Orphans <30 (z 157)
- [ ] `_archive/2026-04/` má archived entries
- [ ] MEMORY-AUTO-INDEX.md má "W5 sweep" sekci
- [ ] Backup: `~/Documents/backups/claude-memory-old-w5-<TS>.tgz`

---

## Wave 7 — Wire/Archive orphan skills (3-4h, LOW-MEDIUM)

### Pre-generated input
- **`~/.claude/audits/2026-05-02-W7-orphan-skills.txt`** — 160 strict orphans z 289 skills (cross-checked rules+hooks+agents+skills)

### Cíl
Reduce 160 orphans → **<50**. Wire (router entry), archive (no value), merge (folded into existing umbrella), or document as util (intentionally simple, no router needed).

### Postup
1. **Read orphan file** + categorize (per skill name pattern):
```bash
cat ~/.claude/audits/2026-05-02-W7-orphan-skills.txt | head -50
```

2. **Triage decision per skill:**
| Decision | Criteria |
|----------|----------|
| **WIRE** | Skill has clear use case, just missing router entry → add 1 line to knowledge-router.md |
| **ARCHIVE** | Stale, redundant, never used (check git log of SKILL.md mtime + transcripts) |
| **MERGE** | Functionality already in umbrella → fold flag/docs |
| **UTIL** | Intentionally simple (e.g. /raw, /trim) — document as util, no router needed |

3. **Bulk wire (prefixes):**
| Prefix | Strategy |
|--------|----------|
| `from-lukas:*` | Add bulk entry "Cherry-picked from Lukas — see CHANGELOG" |
| `axlabs-mckinsey-pptx:*` | Add entry "McKinsey-style decks" |
| `swarm:*` | Add entry "Multi-agent swarm orchestration" |
| `viral:*` | Add entry "Viral content discovery + analytics" |
| `multi-*` | Add entry "Multi-model collaborative" |
| `seo-*` | Add entry "SEO sub-skills" |

4. **Update knowledge-router.md** (min 30+ nových řádků pro reduction <50)

### Acceptance W7
- [ ] Orphans <50 (verified via re-run orphan generator)
- [ ] knowledge-router.md má 30+ nových řádků (`git diff --stat`)
- [ ] No active orphan skill bez SKILL.md
- [ ] Anthropic SDK upgrade decision per-project (per W6 carryover)

---

## Wave 8 — Final commit + notification (30-45 min, NONE)

### Acceptance W8
- [ ] All checkboxy v SESSION-WAVE2-100PCT.md PASS
- [ ] Commit v Codex repo s detail message (full delta W3/W5/W7)
- [ ] Memory entry: `project_wave2_completion_2026_05_02.md` (final synthesis)
- [ ] ntfy: "Wave 2 100% Complete"
- [ ] `/audit-system` warnings 141 → <20 (re-run audit, save report)

### Final commands
```bash
# Final state
ls ~/.claude/skills/ | grep -v '^_' | wc -l
python3 -c "import json; print('MCPs:', len(json.load(open('/Users/filipdopita/.claude/settings.json'))['mcpServers']))"
find ~/.claude/hooks/ -maxdepth 1 -type f \( -name "*.sh" -o -name "*.js" -o -name "*.py" \) | wc -l

# Re-audit
/audit-system

# ntfy
curl -fsS -X POST "https://ntfy.oneflow.cz/Filip" \
  -H "Title: Wave 2 100% COMPLETE" \
  -H "Tags: white_check_mark,rocket" \
  -d "All 8 waves done. Skills <X>, MCPs 14, hooks 43+. Audit warnings 141 → <Y>. Detail v memory project_wave2_final. Dopita."
```

---

## Sub-task delegation pattern (Codex bridge)

Pro file-heavy refactor (W3 splits, W7 bulk wires) použij Codex bridge:
```bash
~/Desktop/Codex/ai-control-plane/scripts/delegate-to-codex.sh ~/.claude \
  "W3.X <skill-name> split/refactor — read source, identify N split points, create new SKILL.md files in <subdir>/, archive original do _archived_2026_05_02_wave2/W3/"
```

Claude orchestruje + verifikuje + commitne. Codex dělá soubory.

---

## Hard rules per session (KRITICKÉ)

1. **Anti-halluci**: každý fact → `[VERIFIED]/[LIKELY]/[GUESS]/[UNCERTAIN]` markers
2. **Completion-mandate**: 3 alternativy než reportu blokátor, žádné "to nejde", autoroute "udělej úplně"
3. **Hard-stop**: jen platby/odeslání/destrukce/FB/strategy >100k Kč → ptát; vše ostatní → rozhodni sám
4. **Mv ne rm**: vše do `_archived_2026_05_02_wave2/W<N>/` nebo `_archive/<rok>-<měsíc>/`
5. **Atomic commits**: per skill refactor / per category sweep, ne batch dump
6. **Pre-flight každou session**: snapshot + re-read rules
7. **/clear na začátku**: fresh context, max 1 wave per session
8. **MCP context7 verify**: pro každou library reference v code → `mcp__context7__query-docs` před write

---

## Rollback (any wave)

```bash
# Skill restore (W3)
mv ~/.claude/skills/_archived_2026_05_02_wave2/W3/* ~/.claude/skills/

# Settings restore (W6 MCPs)
cp ~/.claude/settings.json.bak.20260502_233946 ~/.claude/settings.json

# Memory restore (W5)
mv ~/.claude/projects/-Users-filipdopita/memory/_archive/2026-04/* \
   ~/.claude/projects/-Users-filipdopita/memory/

# Git revert (poslední W2 commit)
cd ~/Desktop/Codex && git log --oneline -5
git revert <commit-hash> --no-edit
```

---

## Quick start nové session

```bash
# 1. /clear (fresh context, MCP context7+time loaded)
# 2. Open this file
cat ~/Desktop/Codex/SESSION-WAVE2-PICKUP-V2.md

# 3. Verify pre-flight (4 commands max)
find ~/.claude/skills/ -maxdepth 1 -mindepth 1 -not -name "_*" | wc -l   # 289
find ~/.claude/skills/ -maxdepth 1 -mindepth 1 -name "gsd-*" -not -name "_*" | wc -l  # 56
python3 -c "import json; print(len(json.load(open('/Users/filipdopita/.claude/settings.json'))['mcpServers']))"  # 14
git -C ~/Desktop/Codex log --oneline -5

# 4. Pick wave per dependency (W3 nebo W5 nebo W7 — všechny independent)
# 5. Backup → execute → smoke test → commit → memory append
```

---

**Dopita** — fresh-context handoff V2, all facts verified 2026-05-02 23:42, learnings z W1+W2+W4+W6 zaintegrované.

**Progress:** 4/8 waves done (W1, W2, W4, W6). Zbývá 4 (W3, W5, W7, W8). ETA do 100%: ~9-13h v 4 sessions.
