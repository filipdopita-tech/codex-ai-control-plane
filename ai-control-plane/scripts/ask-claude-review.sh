#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: ask-claude-review.sh PROJECT_PATH "review request"

Sends a structured review/strategic question to Claude Code (Sonnet)
against PROJECT_PATH. Writes handoff + result into
ai-control-plane/handoffs/.

Use after Codex makes risky changes (security, refactor, deploy gates).
Don't use after every small change.

Exit codes:
  0  review ran (Claude output captured)
  1  bad usage
  2  project path missing
EOF
  exit "${1:-1}"
}

if [ "${1:-}" = "--help" ] || [ "${1:-}" = "-h" ]; then
  usage 0
fi

[ $# -ge 2 ] || usage

PROJECT="$1"
shift
TASK="$*"

if [ ! -d "$PROJECT" ]; then
  echo "Project path does not exist: $PROJECT" >&2
  exit 2
fi

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HANDOFF="$("$ROOT/scripts/handoff.sh" claude "$PROJECT" "$TASK")"
RESULT="${HANDOFF%.md}.result.md"

{
  echo "# Claude Review Result"
  echo
  echo "- Handoff: $HANDOFF"
  echo "- Project: $PROJECT"
  echo "- Started: $(date -u +"%Y-%m-%dT%H:%M:%SZ")"
  echo
  echo "## Output"
  echo
  echo '```text'
  claude -p --model sonnet --permission-mode auto --add-dir "$PROJECT" < "$HANDOFF"
  echo '```'
  echo
  echo "- Finished: $(date -u +"%Y-%m-%dT%H:%M:%SZ")"
} | tee "$RESULT"

echo
echo "Saved result: $RESULT"

