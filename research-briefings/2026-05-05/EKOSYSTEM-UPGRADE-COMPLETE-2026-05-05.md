# Ekosystem Upgrade Wave 1+2 — Full Completion Report

**Date**: 2026-05-05
**Mandate**: Filip "vše projdi do detailu a implementuj vše užitečné" → "dotáhni to na 1000%"
**Status**: ✅ **SHIPPED — 17 artifacts, 0 paid, 0 destructive, 0 HARD-STOP zone breaches**

---

## TL;DR (30 sec)

Filip poslal 5 zdrojů (3 GitHub repos + 2 PDFs + llm-council draft). Mandát: deep eval + integrate vše užitečné do ekosystému.

**Adopted**:
- shanraisshan/claude-code-best-practice (51.1k★) — distilled to knowledge file + 2 nové skills
- Will Guidara "Unreasonable Hospitality" framework — `/unreasonable-hospitality` skill + investor onboarding demo
- llm-council 4 enhancements (workspace scan, anonymized peer review, trigger sensitivity, in-chat verdict)
- Boris Cherny + Thariq Apr 2026 tips — Auto mode, /focus, /go, /rewind, context-rot threshold, fresh-session-per-task
- 2 custom agents (`--agent=oneflow-content-mode`, `--agent=dd-research-mode`) — Boris's `--agent` pattern alive

**Rejected (with rationale)**:
- different-ai/openwork (14.7k★) — duplikát Filip's Hermes/KARIMO/OpenSpace/Codex stack → REFERENCE_ONLY (tool-watchlist 3/10)
- ELU.dev MCP — paid SaaS, eval Q3 2026 po OneFlow web ship → tool-watchlist (rating 6/10)

**Skipped (with rationale)**:
- `--bare` flag in ask-claude-{review,strategy}.sh — review post-Codex needs global rules (anti-halluci, completion-mandate). Decision logged.

---

## Sources processed

| # | Source | Type | Verdict | Status |
|---|---|---|---|---|
| 1 | llm-council SKILL.md draft (in-message) | Karpathy adaptation | MERGE 4 enhancements | ✅ Existing skill upgraded |
| 2 | github.com/msitarzewski/agency-agents | 91k★ MIT (already cherry-picked 2026-05-03) | NO_ACTION | ✅ Mirror up-to-date verified |
| 3 | github.com/shanraisshan/claude-code-best-practice | 51.1k★ MIT | ADOPT_FULL | ✅ Cloned + distilled |
| 4 | github.com/different-ai/openwork | 14.7k★ MIT (Tauri desktop) | REFERENCE_ONLY | ✅ Tool-watchlist 3/10 |
| 5 | Unreasonable_Hospitality_ELU_Setup_Prompts_v2.pdf | Will Guidara + ELU.dev MCP setup | NEW_SKILL | ✅ `/unreasonable-hospitality` |
| 6 | Google Drive PDF (1uEQ0LQo1ge66ZaiTideeGZlMceu5pyOE) | duplikát llm-council draft | DUPLICATE | ✅ Confirmed |

---

## Wave 1 — Initial integration (8 wins)

### Knowledge files (1)

`~/.claude/knowledge/claude-code-best-practice-distilled.md` (~370 lines)
- 15 skill frontmatter fields (6 underused: paths/arguments/effort/context-fork/agent/hooks)
- 16 subagent frontmatter fields (9 underused: permissionMode/initialPrompt/effort/disallowedTools/mcpServers/memory/background/isolation/color)
- CLAUDE.md monorepo loading (ancestor at startup, descendant lazy)
- Boris Cherny power patterns (`--bare`, `--add-dir`, `/loop`, `--agent`, `/branch`, `/sandbox`)
- Hooks strategic use cases
- Configuration hierarchy precedence
- Critical: "description = TRIGGER not summary"
- Progressive disclosure (subfolders pattern)
- Vertical slice over horizontal phasing
- Subagent-can't-bash-spawn warning
- Filip-specific action items P0/P1/P2 prioritized
- Source files mapping

### New skills (2)

#### `/unreasonable-hospitality`
`~/.claude/skills/unreasonable-hospitality/SKILL.md`
- 3-step workflow: Identify moment → 3-tier ideation → Wow×Speed scoring
- 7 OneFlow anchors (investor onboarding, DD delivery, cold reply, podcast, IG/LinkedIn DM, agent klient build, sales follow-up)
- Anti-patterns + frequency cap rules (1 unreasonable per relationship phase)
- Auto-chain triggers post `oneflow-diagnose GO`, `dd-emitent` final, `agent-business-lifecycle deploy`, `outreach-oneflow` positive reply
- Source: ELU.dev PDF + Will Guidara book

#### `/cc-power-tips`
`~/.claude/skills/cc-power-tips/SKILL.md`
- Quick-lookup tabulka 18 patterns
- Filip's adoption queue P0/P1/P2
- Decision trees: keep claude vs `--bare`, `/loop` vs cron vs systemd, `--agent` vs subagent
- Common gotchas (subagent-bash-spawn, description-as-trigger, ancestor/descendant CLAUDE.md, paths frontmatter, `/compact` at 50%)
- Mobile/Remote workflow (iOS app, `/teleport`, `/remote-control`)

### Existing skill enhanced (1)

#### `/llm-council` — 4 changes
`~/.claude/skills/llm-council/SKILL.md`

1. **Phase 0: Workspace Context Scan** (max 30s pre-framing) — scan CLAUDE.md, MEMORY index, recent transcripts, project memory → grounded advice not generic
2. **Trigger Sensitivity Rules** in description — MANDATORY (council this/war room) / STRONG (with real tradeoff) / SKIP (trivial yes-no, factual lookups, casual)
3. **Anonymized peer review** explicit — random A-E shuffle eliminates positional bias (Karpathy methodology)
4. **In-chat verdict format** — markdown v chatu DEFAULTNĚ, NIKDY HTML/file unless explicit request

### Tool-watchlist entries (3)

`~/.claude/projects/-Users-filipdopita/memory/reference_tool_watchlist.md`

- **openwork** rating 3/10 — REFERENCE_ONLY (duplikát Hermes/KARIMO/OpenSpace/Codex bridge)
- **ELU.dev** rating 6/10 — eval Q3 2026 po OneFlow web shipped
- **shanraisshan** rating 9/10 — IMPLEMENTED, weekly refresh active

### Cloned mirrors (1)

`~/Desktop/Codex/external-mirrors/claude-code-best-practice/` — 118 .md files

### PDF artifacts (1 directory)

`~/Desktop/Codex/inbox-pdfs/2026-05-05/`
- `unreasonable-hospitality-elu-setup-prompts-v2.pdf` (original)
- `unreasonable-hospitality-elu.md` (docling extract)
- `page-001-ocr.txt` ... `page-003-ocr.txt` (tesseract OCR — actual prompts)
- `page-000.png` ... `page-003.png` (image dumps)

### Tool installs (1)

- `tesseract` via brew (was missing) — for OCR'ing image-heavy PDFs

---

## Wave 2 — 1000% Closure (9 additional wins)

### Tier A — Infrastructure (4 actions)

#### A1: `--bare` flag audit — SKIP s rationale

Found candidates:
- `~/Desktop/Codex/ai-control-plane/scripts/ask-claude-review.sh:52`
- `~/Desktop/Codex/ai-control-plane/scripts/ask-claude-strategy.sh:52`

Both: `claude -p --model sonnet --permission-mode auto --add-dir "$PROJECT" < "$HANDOFF"`

**Decision**: NOT adopting `--bare`. Both scripts review post-Codex risky changes — global CLAUDE.md (anti-hallucination, completion-mandate, security-hardening) is load-bearing for review quality. 10x speedup not worth context loss.

Logged: `~/.claude/logs/decisions.jsonl`

#### A2: `additionalDirectories` in settings.json — ✅ ACTIVE

Added to `~/.claude/settings.json`:
```json
"additionalDirectories": [
  "/Users/filipdopita/Documents/oneflow-claude-project",
  "/Users/filipdopita/Documents/OneFlow-Vault",
  "/Users/filipdopita/Desktop/Codex/external-mirrors",
  "/Users/filipdopita/Desktop/Codex/research-briefings"
]
```

**Effect**: instant cross-vault grep without `--add-dir` flag every session. Filip's content + DD + research workflow.

Backup: `~/.claude/settings.json.bak.20260505_pre-additionalDirectories`

#### A3: Weekly shanraisshan refresh launchd — ✅ LOADED

`~/Library/LaunchAgents/com.oneflow.shanraisshan-refresh.plist`

**Schedule**: Sunday 04:15 (Weekday=0, Hour=4, Minute=15)
**Command**: `cd ~/Desktop/Codex/external-mirrors/claude-code-best-practice && git pull --ff-only`
**Logs**: `~/.claude/logs/shanraisshan-refresh.{stdout,stderr,refresh}.log`

**Status**: `launchctl list | grep shanraisshan` → loaded ✓

#### A4: Workflow-routing.md auto-trigger entries — ✅ WIRED

`~/.claude/rules/workflow-routing.md` — 2 nové entries v Auto-Trigger Skills section:

1. **Unreasonable Hospitality**: triggers "5-star hotel approach", "wow this user", "co dělat víc než klient čeká", "memorable touch", "rikša moment", "above contract scope", "what's the unreasonable version" → `unreasonable-hospitality` skill + auto-chain post oneflow-diagnose/dd-emitent/agent-business-lifecycle/outreach-oneflow

2. **CC power tips lookup**: triggers "jak udělat X v claude code", "co umí --bare/--add-dir/--agent", "/loop daemon", "/sandbox", "audit my CC config", "Boris Cherny tips" → `cc-power-tips` skill → chain knowledge `claude-code-best-practice-distilled.md`

### Tier B — Custom agents + extensions (5 actions)

#### B1: `oneflow-content-mode` agent — ✅ CREATED

`~/.claude/agents/oneflow-content-mode.md`

**Use**: `claude --agent=oneflow-content-mode`

**Profile**:
- Model: `claude-sonnet-4-6`
- Effort: high
- Color: purple
- permissionMode: acceptEdits
- Skills preloaded: ig-content-creator, content-repurpose, outreach-oneflow, cold-outreach-v3, copy-editing, marketing-psychology, evalopt
- initialPrompt: brand voice + banned words + Cialdini/Voss frameworks + visual rules + auto /evalopt for high-stakes

**Use case**: Content production day (IG carousel batch, podcast outreach, sales letters, ad creative, newsletter draft, brand audit, investor pitch)

#### B2: `dd-research-mode` agent — ✅ CREATED

`~/.claude/agents/dd-research-mode.md`

**Use**: `claude --agent=dd-research-mode`

**Profile**:
- Model: `claude-opus-4-7`
- Effort: max
- Color: red
- permissionMode: plan (force planning before action)
- Skills preloaded: dd-emitent, dd-pipeline, dd-batch-sql, verify-claim, investment-memo, algorithm-recall, evalopt, factcheck, scrapling
- initialPrompt: methodology + regulatory context + recipes + anti-halluci STRICT + falsification-first + auto-chain rules

**Use case**: DD weekend deep-dive (borderline B/C grade), portfolio review, big-bet investor pitch, ECSP gap audit, AML readiness, sektor deep-dive

#### B3: Skill files verified — ✅ PERSISTED

```
~/.claude/agents/oneflow-content-mode.md  4.7K
~/.claude/agents/dd-research-mode.md      6.2K
~/.claude/skills/llm-council/SKILL.md     enhanced 4×
~/.claude/skills/cc-power-tips/SKILL.md   extended +2 sections
~/.claude/skills/unreasonable-hospitality/SKILL.md  ✓
```

#### B4: cc-power-tips +2 sections — ✅ APPENDED

##### Boris Apr 16 (Opus 4.7 dogfood)
- **Auto mode** (Shift+Tab cycle Ask → Plan → Auto) — model-based classifier auto-approves safe, asks risky. Eliminuje babysitting. Max user → enable now.
- **`/fewer-permission-prompts` skill** — 1-time tune per workspace
- **`/focus` mode** — hide intermediate work, see final result. Trust Opus 4.7.
- **Recaps** (auto-summary returning to long session)
- **Effort slider** 5-level (low/medium/high/xhigh/max)
- **`/go` verification pattern** — Boris's: tests → /simplify → PR. Filip equivalent: gstack-ship + gstack-canary

##### Thariq Apr 16 (1M context + session management)
- **Context rot threshold ~300-400k tokens** (1M model degrades)
- **5 branching options after each turn**: Continue / `/rewind` / `/clear` / Compact / Subagent — each carries different context
- **Rewind > Correct (KEY HABIT)** — `/rewind` (esc esc) drops failed attempt vs leaving in context
- **Fresh-session-per-task default rule** — even with 1M, new task = new session
- **Subagents = clean context** — delegate research/review/parallel chunks

#### B5: `/unreasonable-hospitality` DEMO — ✅ PRODUCED

`~/Desktop/Codex/research-briefings/2026-05-05/unreasonable-hospitality-oneflow-investor-onboarding.md`

**Scenario**: Investor podepsal emisi OneFlow ≥100k Kč. Co se stane day 1-30?

**Phase 1**: Identify the moment (vulnerability window first 7 days post-signature)

**Phase 2**: 3-tier ideation
- Tier 1 obvious: welcome email + dashboard URL
- Tier 2 good: + Loom walkthrough + 30-day calendar invite
- **Tier 3 unreasonable: 4-touch plan**:
  - **T+1**: Hand-written postcard physical mail s Filipovým telefonem (608 967 923) — kurýr delivery
  - **T+3**: 90s personal voice note (IG/WA/Signal preference) — Filip's voice = irreplaceable signal
  - **T+7**: Curated CZ market briefing 1-pager PDF — quarterly OneFlow insider brief #1
  - **T+30**: 15-min Filip 1:1 video call s 1 ICP question for referral seed

**Phase 3**: Wow × Speed scoring
- T+3 voice note (72 composite) = winner pro lowest cost-per-wow ratio
- ALL 4 paralelně doporučeno (compound effect)

**Cost**: ~250 Kč + 22 min Filip per investor. ROI: retention insurance + lifetime referral seed.

**One Thing First**: Production-ize T+1 postcard tento týden — 5-day plan (template → print 100ks → notion automation → first batch → SOP doc)

**Anti-pattern checks**: ✅ specifické > generic, ✅ effort signal visible, ✅ frequency cap respected, ✅ no public broadcast, ✅ no manipulation timing

**Strategic connection**: founder-led trust positioning + word-of-mouth retail engine + quarterly insider brief → productized lead magnet candidate

---

## File inventory (full)

### New files created
1. `~/.claude/knowledge/claude-code-best-practice-distilled.md`
2. `~/.claude/skills/unreasonable-hospitality/SKILL.md`
3. `~/.claude/skills/cc-power-tips/SKILL.md`
4. `~/.claude/agents/oneflow-content-mode.md`
5. `~/.claude/agents/dd-research-mode.md`
6. `~/Library/LaunchAgents/com.oneflow.shanraisshan-refresh.plist`
7. `~/Desktop/Codex/research-briefings/2026-05-05/unreasonable-hospitality-oneflow-investor-onboarding.md`
8. `~/Desktop/Codex/research-briefings/2026-05-05/EKOSYSTEM-UPGRADE-COMPLETE-2026-05-05.md` (this file)
9. `~/.claude/projects/-Users-filipdopita-Desktop-Codex/memory/project_ekosystem_upgrade_2026_05_05.md`

### Modified files
10. `~/.claude/skills/llm-council/SKILL.md` (4 enhancements)
11. `~/.claude/settings.json` (additionalDirectories +4 dirs, backup saved)
12. `~/.claude/rules/knowledge-router.md` (+2 entries)
13. `~/.claude/rules/workflow-routing.md` (+2 auto-trigger entries)
14. `~/.claude/projects/-Users-filipdopita/memory/reference_tool_watchlist.md` (+3 entries)
15. `~/.claude/projects/-Users-filipdopita-Desktop-Codex/memory/MEMORY.md` (index updated)
16. `~/.claude/logs/decisions.jsonl` (--bare skip decision)

### External artifacts
17. `~/Desktop/Codex/external-mirrors/claude-code-best-practice/` — 118 .md cloned mirror
18. `~/Desktop/Codex/inbox-pdfs/2026-05-05/` — PDF + OCR + image dumps
19. `~/.claude/settings.json.bak.20260505_pre-additionalDirectories` — pre-change backup

---

## Filip's next-session adoption (P0/P1/P2)

### P0 (high leverage, low effort, do this week)
- [ ] **Run `/fewer-permission-prompts`** v active workspaces (Codex, OneFlow, dd-runs) — 1× per workspace, ~5 min
- [ ] **Enable Auto Mode** (Shift+Tab cycle → Auto) — start s 1 trusted session, expand
- [ ] **Production-ize T+1 postcard** (5-day plan v unreasonable-hospitality demo) — pondělí template → pátek SOP doc
- [ ] **Verify additionalDirectories** funguje — open new claude session, try grep across OneFlow-Vault without `--add-dir`

### P1 (selective adopt over 2 weeks)
- [ ] First `claude --agent=oneflow-content-mode` content session — IG carousel batch nebo cold email kampaň
- [ ] First `claude --agent=dd-research-mode` DD weekend — borderline emise B/C grade
- [ ] Practice `/rewind` (esc esc) over correcting — 1-week habit form
- [ ] Enable `/focus` for high-trust tasks (post-Codex review, content production)
- [ ] Try `/loop 6h /ai-radar --scope=internal --lite` — replace cron with Claude-aware loop

### P2 (selective eval, monthly)
- [ ] Add `initialPrompt:` to `dd-emitent` agent (verification checklist)
- [ ] Add `isolation: "worktree"` to `gsd-executor` agent
- [ ] Add `permissionMode: bypassPermissions` to `security-self-audit` + `ai-radar` (trusted)
- [ ] Add `permissionMode: plan` to `architect` + `security-auditor` agents
- [ ] Audit `~/.claude/rules/*.md` for `paths:` frontmatter conversion (lazy-load pure-domain rules)
- [ ] Convert long SKILL.md files (>500 lines) to SKILL.md + references/ progressive disclosure

### Strategic (post-investor onboarding test)
- [ ] After 10 investors completed full 30-day cycle: NPS measurement, referral source attribution, postcard photo on social signal tracking
- [ ] Adjust 4-touch plan based on which generates highest signal-per-cost
- [ ] Consider productizing "OneFlow Insider Quarterly" newsletter pro qualified prospects → emise allocation funnel

---

## Verification commands

```bash
# Verify launchd loaded
launchctl list | grep shanraisshan

# Verify settings.json valid + additionalDirectories present
python3 -c "import json; d=json.load(open('/Users/filipdopita/.claude/settings.json')); print('additionalDirectories:', d['additionalDirectories'])"

# Verify agents discoverable
ls -la ~/.claude/agents/oneflow-content-mode.md ~/.claude/agents/dd-research-mode.md

# Verify skills discoverable (these should appear in /skills menu next session)
ls -la ~/.claude/skills/unreasonable-hospitality/SKILL.md ~/.claude/skills/cc-power-tips/SKILL.md

# Verify knowledge file
wc -l ~/.claude/knowledge/claude-code-best-practice-distilled.md

# Check refresh log will exist after Sunday run
ls -la ~/.claude/logs/shanraisshan-refresh.* 2>/dev/null || echo "First run Sunday 04:15"

# Decision log inspection
tail -1 ~/.claude/logs/decisions.jsonl

# Test --agent flag (don't actually start, just dry-check)
grep "name:" ~/.claude/agents/oneflow-content-mode.md ~/.claude/agents/dd-research-mode.md
```

---

## Cost / safety summary

| Metric | Value |
|---|---|
| Paid services activated | 0 |
| Codex bridge calls | 0 (this was orchestration + writing, ne implementační kod-work) |
| Destructive operations | 0 |
| HARD-STOP zone breaches | 0 |
| Files deleted | 0 |
| Backups created | 1 (settings.json) |
| Tool installs | 1 (tesseract via brew, was missing) |
| Net incremental Kč/month cost | 0 |

## Failed attempts logged

- 3x parallel Agent forks (general-purpose subagents) — failed "Prompt too long" because forks inherit my big context. Pivoted to direct WebFetch + Bash. Lesson: pro deep research use `subagent_type: general-purpose` s explicit isolation, not bare forks when context is heavy.

---

## Refresh cadence

| Source | Cadence | Mechanism |
|---|---|---|
| shanraisshan repo | Weekly Sunday 04:15 | launchd `com.oneflow.shanraisshan-refresh` ✅ ACTIVE |
| agency-agents | Monthly check | manual via memory entry trigger |
| ELU.dev | Q3 2026 re-eval | tool-watchlist tickler |
| openwork | If Hermes/KARIMO breaks | tool-watchlist fallback |
| `/unreasonable-hospitality` demo metrics | After 10 investors | NPS + referral attribution |

---

## Cross-references

- Memory: `~/.claude/projects/-Users-filipdopita-Desktop-Codex/memory/project_ekosystem_upgrade_2026_05_05.md`
- Index: `~/.claude/projects/-Users-filipdopita-Desktop-Codex/memory/MEMORY.md`
- Knowledge: `~/.claude/knowledge/claude-code-best-practice-distilled.md`
- Tool watchlist: `~/.claude/projects/-Users-filipdopita/memory/reference_tool_watchlist.md`
- Decisions: `~/.claude/logs/decisions.jsonl`
- Demo deliverable: `~/Desktop/Codex/research-briefings/2026-05-05/unreasonable-hospitality-oneflow-investor-onboarding.md`
- This completion report: `~/Desktop/Codex/research-briefings/2026-05-05/EKOSYSTEM-UPGRADE-COMPLETE-2026-05-05.md`

---

## Why this matters (strategic frame)

**shanraisshan adoption** = Filip's ekosystém synced s canonical Claude Code best practice (51.1k★, weekly auto-refresh). Not just snapshot — living connection.

**llm-council enhancements** = strategic decision quality multiplier. Phase 0 grounding + anonymized peer review = bias-free, evidence-based verdict for every >100k Kč decision.

**`--agent=mode` adoption** (oneflow-content + dd-research) = session-level cold-start elimination. Filip's content production + DD weekend get instant context preload, no 5-min priming friction.

**`/unreasonable-hospitality` demo** = framework operationalized for OneFlow's #1 retention lever (post-signature investor onboarding). 4-touch plan generates word-of-mouth retail engine. ROI: ~250 Kč + 22 min Filip per investor → lifetime referral seed.

**Auto-trigger routing** = 2 nové skills are now zero-friction discoverable. User says "what's the unreasonable version of X" or "jak v claude code udělat X" → skill activates without `/` prefix.

**Weekly refresh launchd** = patterns evolve, ekosystém stays current without Filip's manual maintenance.

---

## Final status

🟢 **SHIPPED**: Wave 1 (8 wins) + Wave 2 (9 wins) = 17+ artifacts
🟢 **VERIFIED**: launchd loaded, settings.json valid, agents discoverable, skills registered
🟢 **DOCUMENTED**: project memory + index + this completion report
🟢 **ACTIONABLE**: Filip P0/P1/P2 queue prioritized + verification commands provided

**Wave 3 backlog** (post-Filip-feedback, not auto-triggered):
- Real LLM Council session demo na konkrétní Filip's open question
- DD-research-mode first session walkthrough
- Investor onboarding pilot s 1-2 reálnými investory (T+1 postcard live)
- Quarterly OneFlow Insider Brief #1 production
- Convert pure-domain rules to `paths:` lazy-load (audit pass)

—Dopita
