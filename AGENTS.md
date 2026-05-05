# Codex Workspace Operating Rule

This workspace is Filip's AI control plane. Optimize for the strongest practical system quality:

- Keep Codex, Claude Code, VS Code, Google Cloud tooling, local Mac tooling, and VPS handoffs compatible and observable.
- Prefer working, verified automation over vague setup notes.
- Preserve existing user configuration and never remove secrets, aliases, hooks, or project state without explicit instruction.
- Run healthchecks or targeted verification after meaningful changes.
- Balance intelligence and cost: use full plugin/MCP context for cloud, browser, Drive/Gmail/Calendar, docs, and complex repo work; use lean modes for narrow code tasks and simple checks.
- Avoid unbounded AI-to-AI loops. Use structured handoffs with concrete project paths, tasks, verification, and residual risk.
- Default to top-tier upkeep for this control plane: broad upgrades, cleanup, autoremove, and verification are acceptable when the user's goal is maximum system quality.

Primary commands:

```bash
./ai-healthcheck.sh
./ai-control-plane/scripts/doctor.sh
./ai-control-plane/scripts/update-core.sh
./ai-control-plane/scripts/delegate-to-codex.sh /path/to/project "task"
./ai-control-plane/scripts/ask-claude-review.sh /path/to/project "review request"
./ai-control-plane/scripts/verify-codex-result.sh /path/to/project   # anti-halucinace gate
```

After every Codex delegation, an anti-halucinace gate runs automatically:
captures real `git diff` in the target project and flags claim/diff
mismatches. Disable per-call with `AI_BRIDGE_VERIFY=0`. Re-run manually
with `ofs verify /path/to/project`.

Telemetry (Wave 2 added 2026-05-05): every Codex delegation appends a
JSONL record to `~/.claude/logs/bridge-utilization.jsonl` with mode,
duration, exit_code, files_changed, result_kb, handoff/result paths,
and caller. Records survive across sessions. Disable per-call with
`BRIDGE_TELEMETRY_OFF=1`. Query with:
- `ofs bu [today|week|all] [--per-project]` (human summary)
- `bash ~/scripts/automation/bridge-utilization-summary.sh week --json` (machine)
- Weekly retro report (Sunday 09:00) auto-includes utilization section + per-project ratio
- Active-Agents.md dashboard (refresh every 15 min) shows today's stats in COST section
- Prune: weekly Mon 03:00 launchd `cz.oneflow.codex-utilization-prune`
  archives entries >60 days when log exceeds 80KB

Behavior nudge (Wave 1 hook 2026-05-05): when Claude edits 3+ distinct
code files in one project within 90s without delegating, PreToolUse hook
`~/.claude/hooks/bridge-routing-nudge.sh` prints an informational
system-reminder suggesting `/codex <project> "<task>"`. Per-project
cooldown 10 min. Opt-out: `BRIDGE_NUDGE_OFF=1` or `CODEX_BRIDGE_NUDGE=0`.

Slash invocation: `codex <project_path> "<task>"` skill (resolves project
from arg or `$WORKSPACE_DEFAULT` or cwd, picks lean mode by default,
calls delegate via cost-tracker shim → universal telemetry capture).

⚠️ **Terminal vs Claude Code disambiguation**:
- Inside Claude Code session: `/codex <project> "<task>"` → invokes the skill
  wrapper (correct path).
- In terminal: typing `codex` resolves to OpenAI Codex CLI binary at
  `/opt/homebrew/bin/codex` — NOT the skill wrapper. Use one of:
  - `ofs codex <project> "<task>"` (preferred — telemetry path = ofs)
  - `~/.claude/skills/codex/codex.sh <project> "<task>"` (absolute path)
  - Direct: `~/Desktop/Codex/ai-control-plane/scripts/delegate-to-codex.sh "$P" "$T"`

Wave 3 polish (added 2026-05-05):
- Statusline indicator `cd <D>d/<N>n` (today's delegations/nudges, color-coded)
- Daily ntfy summary 21:30 (D≥5 healthy / D 2-4 light / D≤1+N≥3 warning)
- Obsidian heatmap `00-Claude-Dashboard/Codex-Heatmap.md` (Mon 04:00 launchd)
- B1 prefer-deeper-marker: README.md / AGENTS.md count as project-root markers
  for sub-projekt detection (jobs-cz-system → jobs-cz-system, not /Desktop/Codex)
- B2 BRIDGE_CALLER enrichment: telemetry differentiates ofs|skill|cost-tracker|direct|legacy
- B3 atomic JSONL append: mkdir-lock + handoff-path dedup
- B4 plan-mode skip: `CLAUDE_PLAN_MODE=1` silences nudge hook
- A2 weekly-retro action item: bridge ratio threshold (🟢≥70% / 🟡 30-70% / 🔴<30%)
- Legacy backfill: 52 pre-Wave-2 handoffs migrated to telemetry as caller=legacy

Codex CLI version: pinned baseline **codex-cli 0.128.0** (verified 2026-05-05,
recorded in `ai-control-plane/.codex-cli-pinned-version`). Future upgrades:
test with `delegate-to-codex.sh ~/Desktop/Codex "ping"` first; if exit 0 +
output captured + handoff triplet written, upgrade is safe. Otherwise pin back.

Codex/Claude report contract (enforced by handoff template):
1. Changed files (path:lines + rationale) 2. Verification run (commands+outcome)
3. Confidence per claim (`[VERIFIED]`/`[LIKELY]`/`[GUESS]`/`[UNCERTAIN]`)
4. Residual risk. Never omit a section — say "none" if empty.
