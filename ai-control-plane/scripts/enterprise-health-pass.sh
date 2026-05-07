#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
LOG_DIR="$HOME/.claude/logs"
STAMP="$(date '+%Y%m%d-%H%M%S')"
REPORT="$LOG_DIR/enterprise-health-pass-$STAMP.md"

APPLY_UPDATES=0
APPLY_CLEANUP=0
FULL_10_10=0
SKIP_SMOKE=0
SKIP_WORKSPACE=0

usage() {
  cat <<'EOF'
Usage: enterprise-health-pass.sh [options]

Runs a corporate-grade AI control-plane upkeep pass with evidence capture.

Default mode is conservative:
  - check update signals without upgrading
  - record Mac/VPS resource snapshot
  - dry-run MCP stale process cleanup
  - run security audit
  - run ecosystem audit + doctor
  - run Codex bridge smoke test

Options:
  --apply-updates   run update-core.sh in apply mode
  --apply-cleanup   terminate stale duplicate MCP processes selected by the safe cleanup script
  --full-10-10      run verify-10-10.sh; this may create tiny OFS/vault verification records
  --skip-smoke      skip Codex bridge smoke test
  --skip-workspace  skip cross-workspace 1000 pass
  --help            show this help
EOF
}

while [ $# -gt 0 ]; do
  case "${1:-}" in
    --apply-updates)
      APPLY_UPDATES=1
      shift
      ;;
    --apply-cleanup)
      APPLY_CLEANUP=1
      shift
      ;;
    --full-10-10)
      FULL_10_10=1
      shift
      ;;
    --skip-smoke)
      SKIP_SMOKE=1
      shift
      ;;
    --skip-workspace)
      SKIP_WORKSPACE=1
      shift
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      echo "Unknown arg: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

mkdir -p "$LOG_DIR"

pass=0
fail=0

write_header() {
  cat > "$REPORT" <<EOF
# Enterprise Health Pass

- Timestamp: $(date '+%Y-%m-%d %H:%M:%S %Z')
- Root: $ROOT
- apply_updates: $APPLY_UPDATES
- apply_cleanup: $APPLY_CLEANUP
- full_10_10: $FULL_10_10
- skip_smoke: $SKIP_SMOKE
- skip_workspace: $SKIP_WORKSPACE

EOF
}

run_section() {
  local title="$1"
  shift

  echo "== $title =="
  {
    echo
    echo "## $title"
    echo
    echo '```text'
  } >> "$REPORT"

  set +e
  "$@" 2>&1 | tee -a "$REPORT"
  local status_code=${PIPESTATUS[0]}
  set -e

  echo '```' >> "$REPORT"
  if [ "$status_code" -eq 0 ]; then
    pass=$((pass + 1))
    echo "- Result: PASS" >> "$REPORT"
    echo "PASS $title"
  else
    fail=$((fail + 1))
    echo "- Result: FAIL exit=$status_code" >> "$REPORT"
    echo "FAIL $title exit=$status_code"
  fi
  echo
  return "$status_code"
}

write_header

run_section "Git State" git -C "$ROOT" status --short --branch || true

if [ "$APPLY_UPDATES" -eq 1 ]; then
  run_section "Core Updates" "$ROOT/ai-control-plane/scripts/update-core.sh" || true
else
  run_section "Core Update Signals" "$ROOT/ai-control-plane/scripts/update-core.sh" --check-only || true
fi

run_section "Resource Snapshot" "$ROOT/ai-control-plane/scripts/resource-monitor.sh" || true
run_section "Mac Load Triage" "$ROOT/ai-control-plane/scripts/mac-load-triage.sh" || true
run_section "MCP Process Audit" "$ROOT/ai-control-plane/scripts/mcp-process-audit.sh" || true

if [ "$APPLY_CLEANUP" -eq 1 ]; then
  run_section "MCP Stale Cleanup" "$ROOT/ai-control-plane/scripts/mcp-process-cleanup.sh" --apply --older-than-min 30 || true
else
  run_section "MCP Stale Cleanup Dry Run" "$ROOT/ai-control-plane/scripts/mcp-process-cleanup.sh" --older-than-min 30 || true
fi

run_section "Security Audit" "$ROOT/ai-control-plane/scripts/security-audit.sh" || true
run_section "Ecosystem Audit" "$ROOT/ai-control-plane/scripts/ecosystem-audit.sh" || true
run_section "Doctor" "$ROOT/ai-control-plane/scripts/doctor.sh" || true

if [ "$SKIP_WORKSPACE" -eq 0 ]; then
  run_section "Workspace 1000 Pass" "$ROOT/ai-control-plane/scripts/workspace-1000-pass.sh" || true
fi

if [ "$SKIP_SMOKE" -eq 0 ]; then
  run_section "Codex Bridge Smoke" "$ROOT/ai-control-plane/scripts/codex-bridge-smoke.sh" || true
fi

if [ "$FULL_10_10" -eq 1 ]; then
  run_section "10/10 Verification" "$ROOT/ai-control-plane/scripts/verify-10-10.sh" || true
fi

{
  echo
  echo "## Summary"
  echo
  echo "- Pass sections: $pass"
  echo "- Failed sections: $fail"
  echo "- Report: $REPORT"
} >> "$REPORT"

echo "Enterprise health pass complete"
echo "Report: $REPORT"
echo "Pass sections: $pass"
echo "Failed sections: $fail"

[ "$fail" -eq 0 ]
