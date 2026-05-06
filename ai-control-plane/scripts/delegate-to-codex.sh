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
PROJECT="$(cd "$PROJECT" && pwd)"

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
# Also capture HEAD commit so verify gate can detect Codex-made commits
# (Codex with --sandbox workspace-write can run `git commit` itself).
BEFORE_SNAPSHOT=""
BEFORE_HEAD=""
if [ -d "$PROJECT/.git" ]; then
  BEFORE_SNAPSHOT="$(mktemp -t codex-before.XXXXXX)"
  git -C "$PROJECT" status --porcelain > "$BEFORE_SNAPSHOT" 2>/dev/null || true
  BEFORE_HEAD="$(git -C "$PROJECT" rev-parse HEAD 2>/dev/null || true)"
fi

START_EPOCH="$(date +%s)"

set +e
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
  CODEX_EXIT=$?
  echo '```'
  echo
  echo "- Finished: $(date -u +"%Y-%m-%dT%H:%M:%SZ")"
  exit "$CODEX_EXIT"
} | tee "$RESULT"
DELEGATE_EXIT_CODE=${PIPESTATUS[0]}
set -e

echo
echo "Saved result: $RESULT"

# Anti-hallucination gate: capture real git diff in target project + flag
# claim/diff mismatches. Read-only; never fails the parent. Disable via
# AI_BRIDGE_VERIFY=0. Pass before-snapshot so verify can compute real delta.
if [ "${AI_BRIDGE_VERIFY:-1}" = "1" ] && [ -x "$ROOT/scripts/verify-codex-result.sh" ]; then
  echo
  CODEX_BEFORE_SNAPSHOT="$BEFORE_SNAPSHOT" \
  CODEX_BEFORE_HEAD="$BEFORE_HEAD" \
    "$ROOT/scripts/verify-codex-result.sh" "$PROJECT" "$RESULT" || true
fi

# ─── INLINE TELEMETRY (Wave 2 — universal, works for ALL callers) ───
# Skip if BRIDGE_TELEMETRY_OFF=1 OR if invoked from cost-tracker (which has its own logging — back-compat).
if [ "${BRIDGE_TELEMETRY_OFF:-0}" != "1" ] && [ "${COST_TRACKER_INVOKING:-0}" != "1" ]; then
  END_EPOCH="$(date +%s)"
  DURATION=$((END_EPOCH - ${START_EPOCH:-$END_EPOCH}))
  TELEMETRY_LOG="$HOME/.claude/logs/bridge-utilization.jsonl"
  mkdir -p "$(dirname "$TELEMETRY_LOG")" 2>/dev/null

  # Files changed delta (relative to BEFORE_SNAPSHOT) — count net new modifications
  FILES_CHANGED=0
  if [ -d "$PROJECT/.git" ] && [ -n "$BEFORE_SNAPSHOT" ] && [ -f "$BEFORE_SNAPSHOT" ]; then
    AFTER_COUNT="$(git -C "$PROJECT" status --porcelain 2>/dev/null | wc -l | tr -d ' ')"
    BEFORE_COUNT="$(wc -l < "$BEFORE_SNAPSHOT" 2>/dev/null | tr -d ' ')"
    FILES_CHANGED=$((AFTER_COUNT - BEFORE_COUNT))
    [ "$FILES_CHANGED" -lt 0 ] && FILES_CHANGED=0
  fi

  RESULT_KB=0
  [ -f "$RESULT" ] && RESULT_KB="$(du -k "$RESULT" 2>/dev/null | awk '{print $1}')"

  PROJECT_SHORT="$(basename "$PROJECT")"
  TASK_CHARS=${#TASK}
  ESC_PROJECT="$(printf '%s' "$PROJECT" | sed 's/"/\\"/g')"
  ESC_PROJECT_SHORT="$(printf '%s' "$PROJECT_SHORT" | sed 's/"/\\"/g')"
  ESC_HANDOFF="$(printf '%s' "${HANDOFF:-}" | sed 's/"/\\"/g')"
  ESC_RESULT="$(printf '%s' "${RESULT:-}" | sed 's/"/\\"/g')"

  # B3 (2026-05-05): atomic write via mkdir-lock + handoff-path dedup.
  # Handoff is timestamp-unique, so dedup only fires on retry/double-emit
  # within the same script invocation. Lock bounds concurrent telemetry
  # writes from parallel delegates (no torn-line risk on JSONL append).
  ALREADY_LOGGED=0
  if [ -n "$ESC_HANDOFF" ] && [ -f "$TELEMETRY_LOG" ]; then
    if tail -n 200 "$TELEMETRY_LOG" 2>/dev/null | grep -qF "\"handoff\":\"$ESC_HANDOFF\""; then
      ALREADY_LOGGED=1
    fi
  fi

  if [ "$ALREADY_LOGGED" = "0" ]; then
    LOCK_DIR="${TELEMETRY_LOG}.lock"
    LOCK_OK=0
    for _try in 1 2 3 4 5; do
      if mkdir "$LOCK_DIR" 2>/dev/null; then
        LOCK_OK=1
        break
      fi
      # stale-lock GC (>30s old)
      if [ -d "$LOCK_DIR" ]; then
        LOCK_AGE=$(($(date +%s) - $(stat -f %m "$LOCK_DIR" 2>/dev/null || echo 0)))
        [ "$LOCK_AGE" -gt 30 ] && rmdir "$LOCK_DIR" 2>/dev/null
      fi
      sleep 0.3
    done

    printf '{"ts":"%s","event":"delegate","project":"%s","project_short":"%s","mode":"%s","task_chars":%s,"duration_s":%s,"exit_code":%s,"files_changed":%s,"result_kb":%s,"handoff":"%s","result":"%s","caller":"%s"}\n' \
      "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
      "$ESC_PROJECT" "$ESC_PROJECT_SHORT" "$MODE" "$TASK_CHARS" "$DURATION" "$DELEGATE_EXIT_CODE" \
      "$FILES_CHANGED" "$RESULT_KB" "$ESC_HANDOFF" "$ESC_RESULT" "${BRIDGE_CALLER:-direct}" \
      >> "$TELEMETRY_LOG" 2>/dev/null || true

    [ "$LOCK_OK" = "1" ] && rmdir "$LOCK_DIR" 2>/dev/null || true
  fi
fi

# Cleanup snapshot tmpfile
[ -n "$BEFORE_SNAPSHOT" ] && rm -f "$BEFORE_SNAPSHOT" 2>/dev/null || true

exit "${DELEGATE_EXIT_CODE:-0}"
