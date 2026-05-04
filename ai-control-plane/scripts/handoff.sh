#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: handoff.sh codex|claude PROJECT_PATH "task"

Creates a structured handoff markdown file in ai-control-plane/handoffs/
with the task description, operating rules, and a suggested CLI command.
Prints the handoff path to stdout.

Used internally by delegate-to-codex.sh and ask-claude-review.sh,
but can be called standalone for manual review of the prompt.
EOF
  exit "${1:-1}"
}

if [ "${1:-}" = "--help" ] || [ "${1:-}" = "-h" ]; then
  usage 0
fi

[ $# -ge 3 ] || usage

TARGET="$1"
PROJECT="$2"
shift 2
TASK="$*"

case "$TARGET" in
  codex|claude) ;;
  *) usage ;;
esac

if [ ! -d "$PROJECT" ]; then
  echo "Project path does not exist: $PROJECT" >&2
  exit 2
fi

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HANDOFF_DIR="$ROOT/handoffs"
mkdir -p "$HANDOFF_DIR"

STAMP="$(date +%Y%m%d-%H%M%S)"
SAFE_NAME="$(basename "$PROJECT" | tr ' /' '__' | tr -cd 'A-Za-z0-9._-')"
FILE="$HANDOFF_DIR/${STAMP}-${TARGET}-${SAFE_NAME}.md"

cat > "$FILE" <<EOF
# AI Handoff

- Target: $TARGET
- Project: $PROJECT
- Created: $(date -u +"%Y-%m-%dT%H:%M:%SZ")

## Task

$TASK

## Operating Rules

- Read relevant files first; do not assume structure.
- Use real ground truth first: \`pwd\`, \`git status\`, \`rg\`, \`ls\`, tests, build logs, healthchecks, and actual command output.
- Change only what is necessary for this task. No drive-by refactors.
- Do not print, copy, or include secrets, tokens, .env values in the report.
- Prefer existing project patterns and conventions.
- Run available tests, lint, or a project healthcheck after edits.
- Stop on the first irrecoverable error and report it instead of guessing.
- Do not claim completion because a plan sounds plausible; claim completion only for work you actually performed.
- If something cannot be verified, label it \`[UNCERTAIN]\` and include the reason plus the exact next verification step.
- Keep the loop bounded: do the requested task, verify it, report residual risk, then stop.

## Required Report Sections

End your output with these four sections, in this order:

1. **Changed files** — list of files touched (\`path:lines\` if surgical), with one-line per-file rationale.
2. **Verification run** — exact commands you ran (tests, build, healthcheck) plus their pass/fail outcome.
3. **Confidence** — per non-trivial claim, tag one of:
   - \`[VERIFIED]\` ran in this handoff and observed result
   - \`[LIKELY]\` based on code reading, not executed
   - \`[GUESS]\` heuristic, low evidence
   - \`[UNCERTAIN]\` unable to verify; needs human follow-up
4. **Residual risk** — what could still break (edge cases, untested paths, integrations).

If a section has no content, state \`none\` explicitly. Do not omit sections.

## Suggested Command

EOF

if [ "$TARGET" = "codex" ]; then
  cat >> "$FILE" <<EOF
\`\`\`bash
codex exec --cd "$PROJECT" --sandbox workspace-write --skip-git-repo-check < "$FILE"
\`\`\`
EOF
else
  cat >> "$FILE" <<EOF
\`\`\`bash
claude -p --model sonnet --permission-mode auto --add-dir "$PROJECT" < "$FILE"
\`\`\`
EOF
fi

echo "$FILE"
