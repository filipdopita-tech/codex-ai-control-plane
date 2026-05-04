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

Codex/Claude report contract (enforced by handoff template):
1. Changed files (path:lines + rationale) 2. Verification run (commands+outcome)
3. Confidence per claim (`[VERIFIED]`/`[LIKELY]`/`[GUESS]`/`[UNCERTAIN]`)
4. Residual risk. Never omit a section — say "none" if empty.
