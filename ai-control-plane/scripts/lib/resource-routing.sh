#!/usr/bin/env bash
# Shared Mac-pressure / Flash-offload routing helpers.
# Read-only: gathers real metrics and emits deterministic routing decisions.

resource_vps_status() {
  local wg="${VPS_WG:-root@10.77.0.1}"
  local public="${VPS_PUBLIC:-root@173.212.220.67}"
  if ssh -o ConnectTimeout=3 -o BatchMode=yes "$wg" "true" 2>/dev/null; then
    echo "wg"
  elif ssh -o ConnectTimeout=3 -o BatchMode=yes "$public" "true" 2>/dev/null; then
    echo "public"
  else
    echo "down"
  fi
}

resource_mac_snapshot() {
  local load1 swap_total swap_used swap_pct pressure
  load1="$(uptime | awk -F'load averages:' '{print $2}' | awk '{print $1}' | tr -d ', ')"
  if sysctl vm.swapusage 2>/dev/null | grep -q total; then
    swap_total="$(sysctl vm.swapusage | grep -oE 'total = [0-9]+\.[0-9]+M' | grep -oE '[0-9]+\.[0-9]+' | head -1)"
    swap_used="$(sysctl vm.swapusage | grep -oE 'used = [0-9]+\.[0-9]+M' | grep -oE '[0-9]+\.[0-9]+' | head -1)"
    swap_pct="$(awk "BEGIN {printf \"%.0f\", ($swap_used / $swap_total) * 100}")"
  else
    swap_total=0; swap_used=0; swap_pct=0
  fi
  pressure="$(sysctl -n kern.memorystatus_level 2>/dev/null || echo 0)"
  printf "%s|%s|%s|%s" "${load1:-0}" "${swap_pct:-0}" "${pressure:-0}" "${swap_used:-0}"
}

resource_mac_stressed() {
  local load1="${1:-0}" swap_pct="${2:-0}" pressure="${3:-0}"
  awk "BEGIN {exit !($load1 > 6)}" 2>/dev/null && return 0
  [ "$swap_pct" -ge "${AI_ROUTER_SWAP_THRESHOLD:-75}" ] && return 0
  [ "$pressure" -gt 0 ] && [ "$pressure" -lt 40 ] && return 0
  return 1
}

resource_task_is_heavy() {
  local task_lc
  task_lc="$(printf '%s' "${1:-}" | tr '[:upper:]' '[:lower:]')"
  printf '%s' "$task_lc" | grep -qiE '\b(heavy|long-running|large|mass|batch|crawl|crawler|scrape|scraper|scraping|research|enrich|etl|data-os|apify|playwright|browser|screenshot|lighthouse|benchmark|load test|next build|build|rebuild|test|tests|jest|vitest|pytest|prisma|docker|deploy|deployment|vps|flash|remote|server|sync|video|render|scrap|scrapling|t[eě]žk|dlouh|sestav|otestuj|nasadit|produkce)\b'
}

resource_should_offload_to_vps() {
  local task="${1:-}"
  [ "${AI_ROUTER_VPS_OFFLOAD:-1}" = "0" ] && return 1
  [ "${AI_ROUTER_FORCE_LOCAL:-0}" = "1" ] && return 1
  resource_task_is_heavy "$task" || return 1

  local load1 swap_pct pressure swap_used vps_state
  IFS='|' read -r load1 swap_pct pressure swap_used < <(resource_mac_snapshot)
  resource_mac_stressed "$load1" "$swap_pct" "$pressure" || return 1

  vps_state="$(resource_vps_status)"
  [ "$vps_state" = "wg" ] || [ "$vps_state" = "public" ] || return 1

  RESOURCE_ROUTE_LOAD="$load1"
  RESOURCE_ROUTE_SWAP_PCT="$swap_pct"
  RESOURCE_ROUTE_PRESSURE="$pressure"
  RESOURCE_ROUTE_SWAP_USED="$swap_used"
  RESOURCE_ROUTE_VPS_STATE="$vps_state"
  return 0
}

resource_remote_task_payload() {
  local project="$1" task="$2"
  cat <<EOF
REMOTE-FLASH OFFLOAD TASK.

Run this on Flash VPS compute, not on the Mac. Use only files/services available on Flash. If the target project or required files are not present on Flash, stop with a clear missing-prerequisite report instead of falling back to Mac-local execution.

Mac project reference: $project

Required report contract:
1. Changed files or remote paths touched.
2. Verification run with commands and outcomes.
3. Confidence per claim: [VERIFIED]/[LIKELY]/[GUESS]/[UNCERTAIN].
4. Residual risk.

Task:
$task
EOF
}
