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

- Read relevant files first.
- Change only what is necessary for this task.
- Do not print or copy secrets.
- Prefer existing project patterns.
- Run available tests or a project healthcheck.
- Finish with changed files, verification, and residual risks.

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
