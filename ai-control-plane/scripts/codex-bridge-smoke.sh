#!/usr/bin/env bash
# codex-bridge-smoke.sh — smoke test for Codex bridge anti-halucination gate.
#
# Runs the cheapest possible Codex call ("return literal text, no edits") and
# checks that:
#   1. Codex CLI is reachable
#   2. delegate-to-codex.sh wrapper executes
#   3. verify-codex-result.sh produces a verdict
#   4. Verdict is OK_NOOP (Codex returned text without making file changes)
#
# Output: status line to stdout + JSONL log entry. Exits non-zero on regression.
# Suitable for manual runs and the installed launchd smoke schedule:
# short timeout, low usage, no UI. This script does not self-install launchd.
#
# Filip rules: anti-halluci real probe, cost-aware (1 Codex call/day max), no
# secrets in output. Disable temporarily via SMOKE_OFF=1.

set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LOG="$HOME/.claude/logs/codex-bridge-smoke.jsonl"
mkdir -p "$(dirname "$LOG")"

ts() { date -u '+%Y-%m-%dT%H:%M:%SZ'; }

if [ "${SMOKE_OFF:-0}" = "1" ]; then
  echo "smoke-skipped (SMOKE_OFF=1)"
  printf '{"ts":"%s","verdict":"SKIP","reason":"SMOKE_OFF"}\n' "$(ts)" >> "$LOG"
  exit 0
fi

# Bridge availability gate
if [ ! -x "$ROOT/scripts/delegate-to-codex.sh" ] || [ ! -x "$ROOT/scripts/verify-codex-result.sh" ]; then
  echo "smoke-fail bridge scripts missing"
  printf '{"ts":"%s","verdict":"FAIL","reason":"missing_scripts"}\n' "$(ts)" >> "$LOG"
  exit 2
fi

if ! command -v codex >/dev/null 2>&1; then
  echo "smoke-fail codex CLI not in PATH"
  printf '{"ts":"%s","verdict":"FAIL","reason":"no_codex_cli"}\n' "$(ts)" >> "$LOG"
  exit 3
fi

# Use Codex workspace itself as target (always exists and is git)
TARGET="$ROOT/.."
if [ ! -d "$TARGET/.git" ]; then
  echo "smoke-fail target not a git repo"
  printf '{"ts":"%s","verdict":"FAIL","reason":"not_git"}\n' "$(ts)" >> "$LOG"
  exit 4
fi

# Run smoke test (lean mode = cheapest)
START=$(ts)
OUT=$(AI_BRIDGE_CODEX_MODE=lean "$ROOT/scripts/delegate-to-codex.sh" \
  "$TARGET" \
  "Return exactly: smoke-test-ok. Do not edit files." 2>&1 || true)
END=$(ts)

# Parse verdict from verify output
VERDICT=$(printf '%s' "$OUT" | grep -oE 'Verdict:[[:space:]]+[A-Z_]+' | head -1 | awk '{print $2}')
VERDICT="${VERDICT:-UNKNOWN}"

# Parse Codex output marker
CODEX_RETURNED=0
if printf '%s' "$OUT" | grep -q 'smoke-test-ok'; then
  CODEX_RETURNED=1
fi

# Final verdict logic:
#   - PASS: Codex returned literal + verify says OK_NOOP
#   - SOFT_FAIL: Codex returned literal but made unintended edits
#   - HARD_FAIL: Codex didn't return literal at all
SUMMARY="UNKNOWN"
EXIT=0
if [ "$CODEX_RETURNED" -eq 1 ] && [ "$VERDICT" = "OK_NOOP" ]; then
  SUMMARY="PASS"
elif [ "$CODEX_RETURNED" -eq 1 ]; then
  SUMMARY="SOFT_FAIL"
  EXIT=10
else
  SUMMARY="HARD_FAIL"
  EXIT=20
fi

echo "smoke=$SUMMARY verdict=$VERDICT codex_returned=$CODEX_RETURNED start=$START end=$END"
printf '{"ts":"%s","start":"%s","end":"%s","summary":"%s","verdict":"%s","codex_returned":%d}\n' \
  "$END" "$START" "$END" "$SUMMARY" "$VERDICT" "$CODEX_RETURNED" >> "$LOG"

# ntfy on regression (PASS=silent)
if [ "$SUMMARY" != "PASS" ] && [ -n "${NTFY_TOPIC:-}" ]; then
  curl -s --max-time 4 \
    -H "Title: Codex bridge smoke $SUMMARY" \
    -H "Priority: default" \
    -d "verdict=$VERDICT codex_returned=$CODEX_RETURNED" \
    "https://ntfy.oneflow.cz/$NTFY_TOPIC" >/dev/null 2>&1 || true
fi

exit $EXIT
