#!/usr/bin/env bash
# codex-cost-tracker.sh — BACKWARD-COMPAT shim (Wave 2 2026-05-05)
# Telemetry is now INLINE in delegate-to-codex.sh (works for ALL callers).
# This script remains as thin pass-through for /codex skill + scripts that
# still reference cost-tracker path. Sets COST_TRACKER_INVOKING=1 to prevent
# duplicate telemetry when delegate's inline writer would re-fire.
#
# Original wrapper logic (snapshot, JSONL append, file delta) removed —
# moved to delegate-to-codex.sh § INLINE TELEMETRY.
#
# Implements the spec from handoffs/2026-05-03-cost-tracking-wrapper.md.
# Consumed by ~/scripts/automation/weekly-retro.sh § Bridge utilization.
#
# Usage: codex-cost-tracker.sh PROJECT_PATH "task"
# (same signature as delegate-to-codex.sh — drop-in replacement)
#
# Telemetry record per call:
#   {
#     "ts":             ISO8601 UTC start time
#     "event":          "delegate"
#     "project":        absolute project path
#     "project_short":  basename for grouping
#     "mode":           auto|lean|full (resolved)
#     "task_chars":     length of task description
#     "duration_s":     wallclock seconds
#     "exit_code":      delegate exit code
#     "files_changed":  count from git status diff (project-scoped)
#     "result_kb":      size of result.md (approximation of Codex output volume)
#     "handoff":        path to handoff file
#     "result":         path to result file
#   }
#
# Env:
#   AI_BRIDGE_CODEX_MODE  pass-through to delegate-to-codex.sh
#   AI_BRIDGE_VERIFY      pass-through (default 1)
#   COST_TRACKER_OFF=1    skip telemetry (still runs delegate)

set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DELEGATE="$ROOT/scripts/delegate-to-codex.sh"
LOG="$HOME/.claude/logs/bridge-utilization.jsonl"
mkdir -p "$(dirname "$LOG")" 2>/dev/null

if [ ! -x "$DELEGATE" ]; then
  echo "ERROR: delegate-to-codex.sh not found or not executable: $DELEGATE" >&2
  exit 2
fi

# Mark caller for delegate's inline telemetry (records caller="cost-tracker")
export BRIDGE_CALLER="cost-tracker"

# Pure pass-through to delegate (telemetry happens INLINE there)
exec "$DELEGATE" "$@"
