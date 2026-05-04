#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: delegate-to-codex.sh PROJECT_PATH "task"

Delegates an implementation task to Codex CLI against PROJECT_PATH.
Writes handoff + result into ai-control-plane/handoffs/.

Environment:
  AI_BRIDGE_CODEX_MODE   auto (default) | lean | full
                         auto: keyword-based routing (Google/MCP/browser -> full)
                         lean: gpt-5.5, ignore-user-config (cheap, fast)
                         full: respects ~/.codex/config.toml (plugins, MCP)

Exit codes:
  0  task ran (Codex output captured)
  1  bad usage
  2  project path missing
  3  invalid AI_BRIDGE_CODEX_MODE
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
HANDOFF="$("$ROOT/scripts/handoff.sh" codex "$PROJECT" "$TASK")"
RESULT="${HANDOFF%.md}.result.md"

MODE="${AI_BRIDGE_CODEX_MODE:-auto}"

if [ "$MODE" = "auto" ]; then
  if printf '%s' "$TASK" | grep -qiE '\b(gmail|google drive|gdrive|calendar|kalendář|kalendar|docs|sheets|slides|browser|web|mcp|plugin|cloud|codex cloud|openai docs)\b'; then
    MODE="full"
  else
    MODE="lean"
  fi
fi

case "$MODE" in
  lean)
    CODEX_CMD=(codex exec --ignore-user-config -m gpt-5.5 --cd "$PROJECT" --sandbox workspace-write --skip-git-repo-check)
    ;;
  full)
    CODEX_CMD=(codex exec --cd "$PROJECT" --sandbox workspace-write --skip-git-repo-check)
    ;;
  *)
    echo "Invalid AI_BRIDGE_CODEX_MODE: $MODE (use auto, lean, or full)" >&2
    exit 3
    ;;
esac

# Snapshot project state BEFORE Codex run so verify gate can compute the
# real Codex delta (not the total dirty-tree state). Eliminates the
# "REVIEW: 27 files changed but Codex output not explicit" false-positive
# when working tree already had pending edits unrelated to Codex.
BEFORE_SNAPSHOT=""
if [ -d "$PROJECT/.git" ]; then
  BEFORE_SNAPSHOT="$(mktemp -t codex-before.XXXXXX)"
  git -C "$PROJECT" status --porcelain > "$BEFORE_SNAPSHOT" 2>/dev/null || true
fi

{
  echo "# Codex Result"
  echo
  echo "- Handoff: $HANDOFF"
  echo "- Project: $PROJECT"
  echo "- Mode: $MODE"
  echo "- Started: $(date -u +"%Y-%m-%dT%H:%M:%SZ")"
  echo
  echo "## Output"
  echo
  echo '```text'
  "${CODEX_CMD[@]}" < "$HANDOFF"
  echo '```'
  echo
  echo "- Finished: $(date -u +"%Y-%m-%dT%H:%M:%SZ")"
} | tee "$RESULT"

echo
echo "Saved result: $RESULT"

# Anti-hallucination gate: capture real git diff in target project + flag
# claim/diff mismatches. Read-only; never fails the parent. Disable via
# AI_BRIDGE_VERIFY=0. Pass before-snapshot so verify can compute real delta.
if [ "${AI_BRIDGE_VERIFY:-1}" = "1" ] && [ -x "$ROOT/scripts/verify-codex-result.sh" ]; then
  echo
  CODEX_BEFORE_SNAPSHOT="$BEFORE_SNAPSHOT" "$ROOT/scripts/verify-codex-result.sh" "$PROJECT" "$RESULT" || true
fi

# Cleanup snapshot tmpfile
[ -n "$BEFORE_SNAPSHOT" ] && rm -f "$BEFORE_SNAPSHOT" 2>/dev/null || true
