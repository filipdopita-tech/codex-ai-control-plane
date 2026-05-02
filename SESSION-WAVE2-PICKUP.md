# Wave 2 Pickup — Finální dokončení (W2/W3/W5/W6/W7/W8)

**Vytvořeno:** 2026-05-02 23:20 CEST (po W1+W4 close)
**Předchozí commit:** `8e39d51 docs(wave2): W1+W4 closure — audit false positive + 3 nové hooks`
**Status:** 2/8 waves done. Zbývá 6 waves, ~14-19h práce.
**Master plán:** [`SESSION-WAVE2-100PCT.md`](SESSION-WAVE2-100PCT.md) — referenční bible, neměň, doplňuj jen acceptance checkboxy.

---

## 0. PRE-FLIGHT (povinné na začátku každé session)

```bash
cd ~/Desktop/Codex
echo "=== PICKUP SNAPSHOT $(date -Iseconds) ==="
find ~/.claude/skills/ -maxdepth 1 -mindepth 1 -not -name "_*" | wc -l   # cíl: 305 (W1 baseline)
find ~/.claude/hooks/ -maxdepth 1 -type f \( -name "*.sh" -o -name "*.js" -o -name "*.py" \) | wc -l  # cíl: 43 (W4 baseline)
python3 -c "import json; cfg=json.load(open('/Users/filipdopita/.claude/settings.json')); print('MCPs:', len(cfg['mcpServers']), '| PostToolUse:', len(cfg['hooks']['PostToolUse']), '| Stop:', len(cfg['hooks']['Stop']), '| UPS:', len(cfg['hooks']['UserPromptSubmit']))"  # MCPs:12 PostToolUse:4 Stop:2 UPS:3
git -C ~/Desktop/Codex log --oneline -3
```

**Acceptance:** snapshot odpovídá baseline (skills 305, hooks 43, MCPs 12). Pokud ne → drift, čti `~/.claude/projects/-Users-filipdopita-Desktop-Codex/memory/project_mega_audit_2026_05_02.md` "Wave X closure" sekce.

### Re-read klíčových rules (1× za session)
```bash
head -50 ~/.claude/CLAUDE.md
head -100 ~/.claude/rules/completion-mandate.md
head -80 ~/.claude/rules/anti-hallucination.md
```

### Pre-W2/W3/W5 backup (destruktivní waves)
```bash
TS=$(date +%Y%m%d_%H%M%S)
tar -czf ~/Documents/backups/claude-skills-${TS}.tgz -C ~/.claude skills
cp ~/.claude/settings.json ~/.claude/settings.json.bak.${TS}
cd ~/.claude/projects
tar -czf ~/Documents/backups/claude-memory-old-${TS}.tgz "./-Users-filipdopita"
```

---

## Verified baseline post-W1+W4 (anti-halluci)

| Fact | Value | Source |
|------|-------|--------|
| Skills active | 305 (was 306, W1 -1 gsd-join-discord archived) | `find ... -maxdepth 1 -not -name "_*"` |
| Skills real dirs | 262 | `find ... -type d -not -name "_*"` |
| 0-line SKILL.md (active) | 0 ✅ | `find ... -size 0` |
| Hooks executable | 43 (was 40, W4 +3) | `find ~/.claude/hooks/ -type f` |
| Agents .md | 55 | `find ~/.claude/agents/ -name "*.md"` |
| MCPs | 12 (incl. sequential-thinking from W1 master audit) | settings.json |
| Memory entries (Codex project) | 6 | `ls ~/.claude/projects/-Users-filipdopita-Desktop-Codex/memory/` |
| Backups (TS=20260502_231138) | 4 files, 360 MB | `~/Documents/backups/` |

### W4 hooks installed
- `banned-words-guard.sh` (1916B) → PostToolUse Write|Edit|MultiEdit
- `confidence-marker-postcheck.sh` (1380B) → Stop
- `todowrite-multi-bod-detector.sh` (1517B) → UserPromptSubmit

---

## Lessons learned z W1+W4 (KRITICKÉ pro další waves)

### 1. Audit logic má bug — false positives
W1 odhalil že `/audit-system` označil 6 skills jako "0-line SKILL.md" — všechny měly 23-274 lines real content. **Před archivováním JAKÉHOKOLI skillu vždy:**
```bash
wc -l ~/.claude/skills/<skill>/SKILL.md
head -30 ~/.claude/skills/<skill>/SKILL.md
```
Skip archiv pokud má real content (>20 lines + frontmatter + body).

### 2. pipefail rozbije grep no-match v hooks
```bash
# ŠPATNĚ
set -euo pipefail
COUNT=$(echo "$X" | grep -oE 'pat' | wc -l)  # exit 1 když no match

# DOBŘE
set -eu
COUNT=$( { echo "$X" | grep -oE 'pat' || true; } | wc -l)
# nebo
COUNT=$(echo "$X" | grep -cE 'pat' || echo 0)
```

### 3. tar s dirs co začínají dashem
```bash
# ŠPATNĚ
tar -czf out.tgz -C /path -Users-filipdopita-Desktop-Codex  # tar parsuje jako flags

# DOBŘE
cd /path && tar -czf out.tgz "./-Users-filipdopita-Desktop-Codex"
```

---

## Optimal session split (4 zbývající sessions)

| Session | Waves | Time | Risk | Strategy |
|---------|-------|------|------|----------|
| **2** | W2 (GSD konsolidace) | 3-4h | MEDIUM | 1 wave per session, fresh context, atomic commits per merge |
| **3** | W3 (oversized refactor) | 4-6h | MEDIUM-HIGH | 1 wave per session, 5 sub-tasks (graphify/last30days/mythos/writing/ai-radar) |
| **4** | W5 + W6 paralelně | 4h | LOW-MEDIUM | Memory cleanup ne-blocking s MCP install |
| **5** | W7 + W8 | 2.5h | LOW + NONE | Final wire-up + commit + ntfy |

**Dependency:** W2 → W7. W3, W5, W6 nezávislé. W7 → W8.

---

## Wave 2 — GSD konsolidace (NEXT, MEDIUM risk, 3-4h)

### Strategie
**Cíl:** 73 GSD skills → ≤55 (prefer 50). 32 agents → ≤25. Smaž `gsd-debugger.md.bak.20260501`.

### Top priority merges (per W2.2 plánu)
1. `gsd-debug` + `gsd-forensics` → `/gsd-debug --forensics`
2. `gsd-health` + `gsd-scan` + `gsd-stats` → `/gsd-stats` umbrella
3. Audit umbrella: `/gsd-audit <subcmd>` (audit-fix/audit-milestone/audit-uat/eval-review/validate-phase)
4. Researcher agents dedupe: keep advisor + project, kill redundant
5. Backup soubor: `rm ~/.claude/agents/gsd-debugger.md.bak.20260501`

### Postup
1. Pre-flight + backup (povinné, viz výše)
2. W2.1 mapping — `~/.claude/audits/2026-05-02-W2-gsd-skill-map.txt`
3. Per merge: diff + manuální merge SKILL.md + archive original do `_archived_2026_05_02_wave2/W2/`
4. Smoke test po každém: `/gsd-help` → no deprecation warnings
5. Update `~/.claude/rules/knowledge-router.md` + `workflow-routing.md`

### Anti-pattern (z W1 lekce)
**NEARCHIVUJ** skill bez `wc -l` + `head -30` ověření že obsah je redundantní. GSD skills mohou být wrappers k externím workflow files (`~/.claude/get-shit-done/workflows/*.md`) — kontrola `cat` pomůže.

### Acceptance W2
- [ ] GSD skills 73 → ≤55
- [ ] GSD agents 32 → ≤25
- [ ] `gsd-debugger.md.bak.20260501` smazán
- [ ] `/gsd-help` no deprecation warnings
- [ ] Routing updated v 2 rules souborech

---

## Wave 3 — Oversized refactor (4-6h, MEDIUM-HIGH)

### Targets (verified bytes 2026-05-02)
| Skill | Lines | Strategy | Action |
|-------|-------|----------|--------|
| graphify | 1313 | SPLIT 3-way | graphify-parse + graphify-query + graphify-viz |
| last30days | 881 | EXTRACT patterns | core dispatch + reference/<cat>/.md |
| mythos | 683 | COMPRESS | scenarios → memory pointer |
| writing-skills (662) + copywriting (252) | merge | MERGE → `writing` | dedupe voice/tone/structure |
| ai-radar | 659 | LAZY-LOAD | dispatcher + dimensions/<dim>.md |

### Acceptance W3
- [ ] `find ~/.claude/skills/ -name SKILL.md -size +500c` (kontrolovat lines, ne chars: `awk 'NR > 500'` per file) → 0 active
- [ ] Smoke test PASS: /graphify, /mythos, /ai-radar, /writing, /last30days
- [ ] Routing updated

---

## Wave 5 — Memory orphans (2-3h, LOW-MEDIUM)

### Cíl
Old project memory: 329 files, 172 listed → 157 orphans → **target <30**.

### Postup
1. Generate orphan list (W5.1 commands)
2. Auto-categorize by prefix (auto_, _pending, incident, feedback, knowledge, pm_, project, reference)
3. Apply rules per category (W5.3 tabulka)
4. Bulk update MEMORY-AUTO-INDEX.md (auto_ entries)
5. Bulk archive PROJECT entries >30d → `_archive/2026-04/`
6. Re-count → <30

### Acceptance W5
- [ ] Orphans <30 (z 157)
- [ ] `_archive/2026-04/` má archived entries
- [ ] MEMORY-AUTO-INDEX.md má "W5 sweep" sekci

---

## Wave 6 — Cherry-pick MCPs (3-5h, LOW)

### Verified package names (2026-05-02, anti-halluci)
- ✅ `@upstash/context7-mcp@2.2.3` (real-time lib docs, anti-halluci-blocker)
- ✅ `time-mcp@1.0.6` (NOT `@modelcontextprotocol/server-time` — to je 404!)
- ⚠️ Anthropic SDK upgrade — current 0.86.0, claim 0.97 nutno verify přes `curl https://pypi.org/pypi/anthropic/json`
- ⚠️ Trail of Bits skills — GitHub repo, ne NPM, nutno clone + symlink

### Postup
1. `npx -y @upstash/context7-mcp@latest --help` → ověř fungu
2. Backup settings.json + Python edit pro context7 + time
3. Anthropic SDK research (memory entry decision)
4. Trail of Bits clone + cherry-pick 1-2 nejvyhodnejsi (static-analysis, differential-review)
5. Update knowledge-router.md (3 nové řádky)

### Acceptance W6
- [ ] MCPs 12 → 14 (context7 + time)
- [ ] Both tested live (one tool call each)
- [ ] Anthropic SDK decision documented v memory
- [ ] Trail of Bits 1-2 cherry-picked nebo dokumentováno proč ne

---

## Wave 7 — Wire orphan skills (2-3h, LOW)

### Cíl
276 skills bez router refs → cíl <50. Wire nebo archive batch 3.

### Postup (per W7 plánu)
1. Generate orphans list — `~/.claude/audits/2026-05-02-W7-orphan-skills.txt`
2. Triage (WIRE/ARCHIVE/MERGE/UTIL) per kategorie
3. Bulk wire (prefixes from-lukas:, axlabs-mckinsey-pptx:)
4. Update knowledge-router.md (min 30+ nových řádků)

### Acceptance W7
- [ ] Orphans <50
- [ ] knowledge-router.md má 30+ nových řádků
- [ ] No active orphan skill bez SKILL.md

---

## Wave 8 — Final commit + notification (30-45 min, NONE)

### Acceptance W8
- [ ] All checkboxy v SESSION-WAVE2-100PCT.md PASS
- [ ] Commit v Codex repo s detail message (skills/MCPs/hooks delta)
- [ ] Memory entry: `project_wave2_completion_2026_05_02.md`
- [ ] ntfy: "Wave 2 Complete (100%)"
- [ ] `/audit-system` warnings 141 → <20

### Final commands
```bash
# Final state
ls ~/.claude/skills/ | grep -v '^_' | wc -l
python3 -c "import json; print('MCPs:', len(json.load(open('/Users/filipdopita/.claude/settings.json'))['mcpServers']))"
find ~/.claude/hooks/ -maxdepth 1 -type f \( -name "*.sh" -o -name "*.js" -o -name "*.py" \) | wc -l

# ntfy
curl -fsS -X POST "https://ntfy.oneflow.cz/Filip" \
  -H "Title: Wave 2 Complete (100%)" \
  -H "Tags: white_check_mark,rocket" \
  -d "Skills <X>, MCPs 14, hooks 43+, GSD konsolidace, memory cleanup. Audit warnings 141 → <Y>. Detail v SESSION-WAVE2-100PCT.md. Dopita."
```

---

## Sub-task delegation pattern (Codex bridge)

Pro file-heavy refactor (W2 merges, W3 splits) použij Codex bridge:
```bash
~/Desktop/Codex/ai-control-plane/scripts/delegate-to-codex.sh ~/.claude \
  "W3.1 graphify split — read ~/.claude/skills/graphify/SKILL.md (1313 lines), identify 3 split points (parse/query/viz), create 3 new SKILL.md files in graphify-parse/, graphify-query/, graphify-viz/, archive original do _archived_2026_05_02_wave2/W3/"
```

Claude orchestruje + verifikuje + commitne. Codex dělá soubory.

---

## Hard rules per session (KRITICKÉ)

1. **Anti-halluci**: každý fact → `[VERIFIED]/[LIKELY]/[GUESS]/[UNCERTAIN]` nebo verify command
2. **Completion-mandate**: 3 alternativy než reportu blokátor, žádné "to nejde"
3. **Hard-stop**: jen platby/odeslání/destrukce/FB/strategy >100k Kč → ptát; vše ostatní → rozhodni sám
4. **Mv ne rm**: vše do `_archived_2026_05_02_wave2/W<N>/` nebo `_archive/<rok>-<měsíc>/`
5. **Atomic commits**: per merge/refactor/install, ne batch dump
6. **Pre-flight každou session**: snapshot + re-read rules
7. **/clear na začátku**: fresh context, max 1 wave per session

---

## Rollback (any wave)

```bash
# Skill restore
mv ~/.claude/skills/_archived_2026_05_02_wave2/W<N>/* ~/.claude/skills/

# Settings restore
cp ~/.claude/settings.json.bak.<TS> ~/.claude/settings.json

# Memory restore
mv ~/.claude/projects/-Users-filipdopita/memory/_archive/2026-04/* \
   ~/.claude/projects/-Users-filipdopita/memory/

# Git revert (poslední commit)
cd ~/Desktop/Codex && git revert HEAD --no-edit
```

---

## Quick start nové session

```bash
# 1. /clear
# 2. Open this file
cat ~/Desktop/Codex/SESSION-WAVE2-PICKUP.md

# 3. Verify pre-flight (3 commands max)
find ~/.claude/skills/ -maxdepth 1 -mindepth 1 -not -name "_*" | wc -l
find ~/.claude/hooks/ -maxdepth 1 -type f \( -name "*.sh" -o -name "*.js" -o -name "*.py" \) | wc -l
git -C ~/Desktop/Codex log --oneline -3

# 4. Pick wave (W2 = next per dependency graph)
# 5. Backup → execute → smoke test → commit → memory append
```

---

**Dopita** — fresh-context handoff, all facts verified 2026-05-02 23:20, learnings z W1+W4 zaintegrované.
