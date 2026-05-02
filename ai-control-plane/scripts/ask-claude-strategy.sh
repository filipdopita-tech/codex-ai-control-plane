#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: ask-claude-strategy.sh PROJECT_PATH "strategy request"

Sends a structured strategy/architecture/context question to Claude Code
(Sonnet) against PROJECT_PATH. Writes handoff + result into
ai-control-plane/handoffs/.

Use for planning, architecture, prioritization, long-context synthesis, and
non-editing decisions. Use ask-claude-review.sh for explicit risk gates.

Exit codes:
  0  strategy request ran (Claude output captured)
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
  echo "# Claude Strategy Result"
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
