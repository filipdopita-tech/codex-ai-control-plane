#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: test-bridge.sh [--codex-only|--claude-only]

End-to-end smoke test of the AI bridge:
  1. Codex roundtrip (delegate-to-codex.sh against this workspace)
  2. Claude review roundtrip (ask-claude-review.sh against this workspace)

Each step asks for a single-line answer and verifies a non-empty result
file is produced. Does not modify project files.

Exit codes:
  0  both roundtrips passed
  1  bad usage
  10 codex roundtrip failed
  20 claude roundtrip failed
EOF
  exit "${1:-1}"
}

MODE="all"
case "${1:-}" in
  --help|-h) usage 0 ;;
  --codex-only) MODE="codex" ;;
  --claude-only) MODE="claude" ;;
  "") ;;
  *) echo "Unknown arg: $1" >&2; usage 1 ;;
esac

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORKSPACE="$(cd "$ROOT/.." && pwd)"

PASS=0
FAIL=0

run_step() {
  local label="$1" cmd="$2"
  echo
  echo "▸ $label"
  if eval "$cmd" >/dev/null 2>&1; then
    echo "  PASS"
    PASS=$((PASS + 1))
    return 0
  else
    echo "  FAIL"
    FAIL=$((FAIL + 1))
    return 1
  fi
}

verify_result() {
  local pattern="$1"
  local newest
  newest="$(ls -1t "$ROOT/handoffs/"*.result.md 2>/dev/null | head -1 || true)"
  [ -n "$newest" ] && [ -s "$newest" ] && grep -q "$pattern" "$newest"
}

echo "AI Bridge smoke test"
echo "===================="
echo "workspace: $WORKSPACE"

if [ "$MODE" = "all" ] || [ "$MODE" = "codex" ]; then
  echo
  echo "[1/2] Codex roundtrip (lean mode)"
  if AI_BRIDGE_CODEX_MODE=lean "$ROOT/scripts/delegate-to-codex.sh" \
       "$WORKSPACE" \
       "Vrať jednu větu: 'codex bridge OK'. Nic neměň." \
       >/dev/null 2>&1; then
    if verify_result "codex bridge OK\|bridge OK\|OK"; then
      echo "  PASS — result file contains expected marker"
      PASS=$((PASS + 1))
    else
      echo "  FAIL — result file missing or no marker"
      FAIL=$((FAIL + 1))
      [ "$MODE" = "codex" ] && exit 10
    fi
  else
    echo "  FAIL — delegate-to-codex.sh exited non-zero"
    FAIL=$((FAIL + 1))
    [ "$MODE" = "codex" ] && exit 10
  fi
fi

if [ "$MODE" = "all" ] || [ "$MODE" = "claude" ]; then
  echo
  echo "[2/2] Claude review roundtrip"
  if "$ROOT/scripts/ask-claude-review.sh" \
       "$WORKSPACE" \
       "Vrať jednu větu: 'claude review OK'. Nic neměň." \
       >/dev/null 2>&1; then
    if verify_result "claude review OK\|review OK\|OK"; then
      echo "  PASS — result file contains expected marker"
      PASS=$((PASS + 1))
    else
      echo "  FAIL — result file missing or no marker"
      FAIL=$((FAIL + 1))
      [ "$MODE" = "claude" ] && exit 20
    fi
  else
    echo "  FAIL — ask-claude-review.sh exited non-zero"
    FAIL=$((FAIL + 1))
    [ "$MODE" = "claude" ] && exit 20
  fi
fi

echo
echo "Summary: PASS=$PASS  FAIL=$FAIL"
[ "$FAIL" -eq 0 ] && exit 0
[ "$MODE" = "all" ] && [ "$FAIL" -gt 0 ] && exit 10
exit 1
