#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: route-task.sh [--dry-run] [--json] PROJECT_PATH "task"

Routes a free-form AI task through the local control plane.

The router profiles the task, checks the project registry, writes an
auditable routing decision, then chooses one of these paths:
  - local healthcheck / doctor / update-core
  - Codex lean implementation
  - Codex full implementation with plugin/MCP/browser/cloud context
  - Codex implementation followed by Claude review
  - Claude strategy/review gate

Flags:
  --dry-run   print and audit the decision without running the selected path
  --json      print the decision as JSON instead of the human summary

Environment:
  AI_ROUTER_VERBOSE  1 (default) | 0

Exit codes:
  0  routed successfully
  1  bad usage or internal routing error
  2  project path missing
EOF
  exit "${1:-1}"
}

DRY_RUN=0
JSON_OUT=0

while [ $# -gt 0 ]; do
  case "${1:-}" in
    --help|-h) usage 0 ;;
    --dry-run) DRY_RUN=1; shift ;;
    --json) JSON_OUT=1; shift ;;
    --) shift; break ;;
    -*) echo "Unknown arg: $1" >&2; usage 1 ;;
    *) break ;;
  esac
done

[ $# -ge 2 ] || usage

PROJECT="$1"
shift
TASK="$*"

if [ ! -d "$PROJECT" ]; then
  echo "Project path does not exist: $PROJECT" >&2
  exit 2
fi

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORKSPACE="$(cd "$ROOT/.." && pwd)"
PROJECT_ABS="$(cd "$PROJECT" && pwd)"
LOWER_TASK="$(printf '%s' "$TASK" | tr '[:upper:]' '[:lower:]')"
VERBOSE="${AI_ROUTER_VERBOSE:-1}"
HANDOFF_DIR="$ROOT/handoffs"
mkdir -p "$HANDOFF_DIR"

# Resource-aware guardrail: when Mac swap/load is high and the task is clearly
# heavy, prefer Flash dispatch over adding another local Codex/browser/build job.
# Set AI_ROUTER_FORCE_LOCAL=1 for explicit local override.
# shellcheck source=ai-control-plane/scripts/lib/resource-routing.sh
. "$ROOT/scripts/lib/resource-routing.sh"

has_any() {
  local pattern="$1"
  printf '%s' "$LOWER_TASK" | grep -qiE "$pattern"
}

json_escape() {
  if command -v python3 >/dev/null 2>&1; then
    python3 -c 'import json,sys; print(json.dumps(sys.stdin.read()))'
  else
    sed 's/\\/\\\\/g; s/"/\\"/g; s/^/"/; s/$/"/'
  fi
}

score=0
impl=0
strategy=0
review=0
tooling=0
cloud=0
local_ops=0
maintenance=0
destructive=0
needs_browser=0
needs_docs=0
needs_code=0
needs_tests=0
needs_user_gate=0

reasons=""
signals=""

add_reason() {
  reasons="${reasons}- $1
"
}

add_signal() {
  signals="${signals}${signals:+, }$1"
}

if has_any '\b(fix|repair|bug|implement|add|create|edit|modify|change|refactor|rename|move|split|patch|code|script|automation|feature|opr[aá]v|přidej|vytvoř|uprav|zm[eě]ň|refaktor|automatizaci|funkci)\b'; then
  impl=$((impl + 4)); needs_code=1; score=$((score + 4)); add_signal "implementation"; add_reason "Implementation/edit signal detected."
fi

if has_any '\b(test|tests|build|lint|format|typecheck|ci|pytest|vitest|jest|playwright|healthcheck|doctor|smoke|verify|verification|otestuj|sestav|ověř|over|kontrola)\b'; then
  impl=$((impl + 2)); needs_tests=1; score=$((score + 2)); add_signal "verification"; add_reason "Verification/build/test signal detected."
fi

if has_any '\b(strategy|roadmap|plan|architecture|architectural|copy|copywriting|positioning|brainstorm|analy[sz]e|explain|compare|decide|prioritize|design|strategie|pl[aá]n|architektura|vysvětli|porovnej|rozhodni|prioritizuj|navrhni)\b'; then
  strategy=$((strategy + 4)); score=$((score + 2)); add_signal "strategy"; add_reason "Strategy/analysis signal detected."
fi

if has_any '\b(review|audit|security|risk|regression|approval|approve|gate|threat|privacy|permissions|iam|secret|secrets|bezpečnost|riziko|audit|schválit|oprávnění|tajemství)\b'; then
  review=$((review + 5)); needs_user_gate=1; score=$((score + 3)); add_signal "review-risk"; add_reason "Review/security/risk signal detected."
fi

if has_any '\b(gmail|google drive|gdrive|calendar|kalend[aá]ř|docs|sheets|slides|browser|web|mcp|plugin|connector|openai docs|vscode|vs code|drive|gmailu)\b'; then
  tooling=$((tooling + 5)); score=$((score + 3)); add_signal "tooling"; add_reason "Plugin/MCP/browser/Google tooling signal detected."
fi

if has_any '\b(browser|web|playwright|localhost|127\.0\.0\.1|screenshot|klik|otevři|open)\b'; then
  needs_browser=1
fi

if has_any '\b(docs|sheets|slides|google drive|gdrive|drive|gmail|calendar|kalend[aá]ř)\b'; then
  needs_docs=1
fi

if has_any '\b(cloud|gcloud|vps|server|ssh|deploy|deployment|release|production|prod|terraform|kubernetes|docker|registry|domain|dns|nasadit|produkce|serveru)\b'; then
  cloud=$((cloud + 5)); tooling=$((tooling + 2)); needs_user_gate=1; score=$((score + 5)); add_signal "cloud-vps"; add_reason "Cloud/VPS/deploy signal detected."
fi

if has_any '\b(healthcheck|doctor|diagnostic|diagnostika|scan|status|check setup|ověř setup|zkontroluj setup)\b'; then
  local_ops=$((local_ops + 4)); score=$((score + 2)); add_signal "local-diagnostics"; add_reason "Local diagnostic signal detected."
fi

if has_any '\b(update|upgrade|autoremove|cleanup|brew|core update|aktualizuj|upgraduj|údržba|ukliď)\b'; then
  maintenance=$((maintenance + 4)); local_ops=$((local_ops + 2)); score=$((score + 2)); add_signal "maintenance"; add_reason "Maintenance/update signal detected."
fi

if has_any '\b(delete|remove|destroy|reset|wipe|drop|truncate|reinstall|purge|rm -rf|database|db|datab[aá]z|smazat|smaž|smaz|odstraň|odstranit|znič|znic|resetuj|přeinstaluj|preinstaluj)\b'; then
  destructive=$((destructive + 6)); review=$((review + 3)); needs_user_gate=1; score=$((score + 4)); add_signal "destructive"; add_reason "Potentially destructive signal detected."
fi

PROJECT_NAME="$(basename "$PROJECT_ABS")"
PROJECT_ROLE="unregistered project"
PROJECT_CODEX_READY="unknown"
PROJECT_CLAUDE_READY="unknown"

if command -v jq >/dev/null 2>&1 && [ -f "$ROOT/projects.json" ]; then
  if jq -e --arg path "$PROJECT_ABS" '.core_projects[]? | select(.path == $path)' "$ROOT/projects.json" >/dev/null; then
    PROJECT_NAME="$(jq -r --arg path "$PROJECT_ABS" '.core_projects[]? | select(.path == $path) | .name // "registered project"' "$ROOT/projects.json" | sed -n '1p')"
    PROJECT_ROLE="$(jq -r --arg path "$PROJECT_ABS" '.core_projects[]? | select(.path == $path) | .role // "registered project"' "$ROOT/projects.json" | sed -n '1p')"
    PROJECT_CODEX_READY="$(jq -r --arg path "$PROJECT_ABS" '.core_projects[]? | select(.path == $path) | if has("codex_ready") then .codex_ready else "unknown" end' "$ROOT/projects.json" | sed -n '1p')"
    PROJECT_CLAUDE_READY="$(jq -r --arg path "$PROJECT_ABS" '.core_projects[]? | select(.path == $path) | if has("claude_ready") then .claude_ready else "unknown" end' "$ROOT/projects.json" | sed -n '1p')"
    add_reason "Project profile loaded: $PROJECT_NAME ($PROJECT_ROLE)."
  fi
fi

ACTION="claude_strategy"
CODEX_MODE=""
RISK_LEVEL="low"
REASON_SUMMARY="strategic/default route"
FOLLOWUP_REVIEW=0
RESOURCE_OFFLOAD=0

if resource_should_offload_to_vps "$TASK"; then
  ACTION="vps_dispatch"
  CODEX_MODE=""
  RISK_LEVEL="medium"
  REASON_SUMMARY="Mac resource pressure is high and task is heavy; route to Flash VPS dispatch"
  RESOURCE_OFFLOAD=1
  add_signal "resource-vps"
  add_reason "Resource offload: Mac load=${RESOURCE_ROUTE_LOAD:-?}, swap=${RESOURCE_ROUTE_SWAP_PCT:-?}%, pressure=${RESOURCE_ROUTE_PRESSURE:-?}, VPS=${RESOURCE_ROUTE_VPS_STATE:-?}."
elif [ "$destructive" -gt 0 ] && { [ "$cloud" -gt 0 ] || [ "$impl" -gt 0 ]; }; then
  ACTION="claude_review"
  RISK_LEVEL="critical"
  REASON_SUMMARY="destructive/cloud-changing task needs a Claude gate before execution"
elif [ "$maintenance" -gt 0 ] && [ "$local_ops" -gt 0 ] && [ "$needs_code" -eq 0 ] && [ "$cloud" -eq 0 ]; then
  ACTION="local_update_core"
  RISK_LEVEL="medium"
  REASON_SUMMARY="local maintenance request maps directly to update-core"
elif [ "$local_ops" -gt 0 ] && [ "$needs_code" -eq 0 ] && [ "$cloud" -eq 0 ]; then
  ACTION="local_doctor"
  RISK_LEVEL="low"
  REASON_SUMMARY="local diagnostic request maps directly to doctor"
elif [ "$review" -gt 0 ] && [ "$impl" -eq 0 ]; then
  ACTION="claude_review"
  RISK_LEVEL="high"
  REASON_SUMMARY="review/risk request without implementation signal"
elif [ "$impl" -gt 0 ]; then
  ACTION="codex_delegate"
  RISK_LEVEL="medium"
  CODEX_MODE="lean"
  REASON_SUMMARY="implementation request is best handled by Codex"

  if [ "$tooling" -gt 0 ] || [ "$needs_browser" -eq 1 ] || [ "$needs_docs" -eq 1 ]; then
    CODEX_MODE="full"
    REASON_SUMMARY="implementation needs plugin/MCP/browser/cloud context"
  fi

  if [ "$review" -gt 0 ] || [ "$cloud" -gt 0 ] || [ "$destructive" -gt 0 ]; then
    FOLLOWUP_REVIEW=1
    RISK_LEVEL="high"
    REASON_SUMMARY="implementation should be followed by Claude review because risk signals are present"
  fi

  if [ "$PROJECT_CODEX_READY" = "false" ] && [ "$PROJECT_CLAUDE_READY" = "true" ]; then
    if [ "$review" -gt 0 ] || [ "$cloud" -gt 0 ] || [ "$destructive" -gt 0 ]; then
      ACTION="claude_review"
    else
      ACTION="claude_strategy"
    fi
    CODEX_MODE=""
    FOLLOWUP_REVIEW=0
    RISK_LEVEL="medium"
    REASON_SUMMARY="project registry marks Codex as not ready; route to Claude for planning or handoff"
  fi
elif [ "$tooling" -gt 0 ]; then
  ACTION="codex_delegate"
  CODEX_MODE="full"
  RISK_LEVEL="medium"
  REASON_SUMMARY="tooling/plugin task needs full Codex context"
elif [ "$strategy" -gt 0 ]; then
  ACTION="claude_strategy"
  RISK_LEVEL="low"
  REASON_SUMMARY="strategy/analysis request is best handled by Claude"
fi

STAMP="$(date +%Y%m%d-%H%M%S)"
SAFE_NAME="$(basename "$PROJECT_ABS" | tr ' /' '__' | tr -cd 'A-Za-z0-9._-')"
ROUTE_FILE="$HANDOFF_DIR/${STAMP}-route-${SAFE_NAME}-$$.md"

{
  echo "# AI Routing Decision"
  echo
  echo "- Project: $PROJECT_ABS"
  echo "- Project name: $PROJECT_NAME"
  echo "- Project role: $PROJECT_ROLE"
  echo "- Codex ready: $PROJECT_CODEX_READY"
  echo "- Claude ready: $PROJECT_CLAUDE_READY"
  echo "- Created: $(date -u +"%Y-%m-%dT%H:%M:%SZ")"
  echo "- Action: $ACTION"
  [ -n "$CODEX_MODE" ] && echo "- Codex mode: $CODEX_MODE"
  echo "- Resource offload: $RESOURCE_OFFLOAD"
  echo "- Follow-up review: $FOLLOWUP_REVIEW"
  echo "- Risk: $RISK_LEVEL"
  echo "- Signals: ${signals:-none}"
  echo "- Score: $score"
  echo
  echo "## Task"
  echo
  echo "$TASK"
  echo
  echo "## Reason"
  echo
  echo "$REASON_SUMMARY"
  echo
  echo "## Evidence"
  echo
  printf '%s' "${reasons:-No explicit signals; default route applied.}"
} > "$ROUTE_FILE"

if [ "$JSON_OUT" -eq 1 ]; then
  esc_project="$(printf '%s' "$PROJECT_ABS" | json_escape)"
  esc_action="$(printf '%s' "$ACTION" | json_escape)"
  esc_codex="$(printf '%s' "$CODEX_MODE" | json_escape)"
  esc_risk="$(printf '%s' "$RISK_LEVEL" | json_escape)"
  esc_reason="$(printf '%s' "$REASON_SUMMARY" | json_escape)"
  esc_route="$(printf '%s' "$ROUTE_FILE" | json_escape)"
  printf '{"project":%s,"action":%s,"codex_mode":%s,"risk":%s,"resource_offload":%s,"followup_review":%s,"reason":%s,"route_file":%s}\n' \
    "$esc_project" "$esc_action" "$esc_codex" "$esc_risk" "$RESOURCE_OFFLOAD" "$FOLLOWUP_REVIEW" "$esc_reason" "$esc_route"
elif [ "$VERBOSE" = "1" ]; then
  echo "AI orchestration brain"
  echo "======================"
  echo "Project: $PROJECT_ABS"
  echo "Profile: $PROJECT_NAME"
  echo "Action:  $ACTION"
  [ -n "$CODEX_MODE" ] && echo "Codex:   $CODEX_MODE"
  echo "Risk:    $RISK_LEVEL"
  echo "Offload: $RESOURCE_OFFLOAD"
  echo "Review:  $FOLLOWUP_REVIEW"
  echo "Signals: ${signals:-none}"
  echo "Reason:  $REASON_SUMMARY"
  echo "Audit:   $ROUTE_FILE"
  echo
fi

if [ "$DRY_RUN" -eq 1 ]; then
  exit 0
fi

case "$ACTION" in
  local_doctor)
    "$ROOT/scripts/doctor.sh"
    ;;
  local_update_core)
    "$ROOT/scripts/update-core.sh"
    ;;
  codex_delegate)
    AI_BRIDGE_CODEX_MODE="$CODEX_MODE" "$ROOT/scripts/delegate-to-codex.sh" "$PROJECT_ABS" "$TASK"
    if [ "$FOLLOWUP_REVIEW" -eq 1 ]; then
      "$ROOT/scripts/ask-claude-review.sh" "$PROJECT_ABS" "Review the Codex result for this routed high-risk task. Use the route audit file at $ROUTE_FILE. Original task: $TASK"
    fi
    ;;
  vps_dispatch)
    "$ROOT/scripts/ofs.sh" dispatch "$(resource_remote_task_payload "$PROJECT_ABS" "$TASK")"
    ;;
  claude_review)
    "$ROOT/scripts/ask-claude-review.sh" "$PROJECT_ABS" "$TASK"
    ;;
  claude_strategy)
    "$ROOT/scripts/ask-claude-strategy.sh" "$PROJECT_ABS" "$TASK"
    ;;
  *)
    echo "Internal router error: unknown action $ACTION" >&2
    exit 1
    ;;
esac
