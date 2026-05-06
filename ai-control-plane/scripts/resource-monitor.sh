#!/usr/bin/env bash
# resource-monitor.sh — Mac+VPS+queue load watch + auto-route hint
#
# Reads only (no privilege escalation, no destructive ops).
# Output: JSON snapshot to ~/.claude/logs/resource-monitor.jsonl + ntfy if critical.
# Run: every 5 min via cron (`*/5 * * * * /Users/filipdopita/Desktop/Codex/ai-control-plane/scripts/resource-monitor.sh`)
#
# Filip rules:
#  - Anti-halucinace: real metrics only, no predict
#  - Token efficiency: compact JSONL (~200 bytes/snapshot)
#  - Security: read-only, no shell injection, no eval
#
# Author: Dopita, 2026-05-02

set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LOG="$HOME/.claude/logs/resource-monitor.jsonl"
ALERT_DIR="/tmp/resource-monitor-alerts"
VPS_WG="root@10.77.0.1"
VPS_PUBLIC="root@173.212.220.67"
SSH_OPTS=(-o ConnectTimeout=4 -o BatchMode=yes -o StrictHostKeyChecking=accept-new)

mkdir -p "$(dirname "$LOG")" "$ALERT_DIR"

ts() { date -u '+%Y-%m-%dT%H:%M:%SZ'; }
shell_quote() {
  printf "'%s'" "$(printf '%s' "$1" | sed "s/'/'\\\\''/g")"
}

# ─── Mac metrics ─────────────────────────────────────
mac_load_1=$(uptime | awk -F'load averages:' '{print $2}' | awk '{print $1}' | tr -d ',' | tr -d ' ')
mac_load_5=$(uptime | awk -F'load averages:' '{print $2}' | awk '{print $2}' | tr -d ',' | tr -d ' ')
mac_load_15=$(uptime | awk -F'load averages:' '{print $2}' | awk '{print $3}' | tr -d ',' | tr -d ' ')

if sysctl vm.swapusage 2>/dev/null | grep -q total; then
  swap_total=$(sysctl vm.swapusage | grep -oE 'total = [0-9]+\.[0-9]+M' | grep -oE '[0-9]+\.[0-9]+')
  swap_used=$(sysctl vm.swapusage | grep -oE 'used = [0-9]+\.[0-9]+M' | grep -oE '[0-9]+\.[0-9]+')
  swap_pct=$(awk "BEGIN {printf \"%.0f\", ($swap_used / $swap_total) * 100}")
else
  swap_total=0; swap_used=0; swap_pct=0
fi

mem_pressure=$(sysctl -n kern.memorystatus_level 2>/dev/null || echo 0)

# Top RAM consumer (one-line)
top_ram=$(ps auxw 2>/dev/null | sort -k4 -rn | awk 'NR==2 {printf "%s:%.1f%%", $11, $4}' | head -c 80)

# ─── VPS metrics (fast) ───────────────────────────────
vps_state="down"
vps_load=""
vps_ram_used=""
vps_ram_total=""
vps_disk_pct=""
conductor_inbox=0
conductor_active=0

if ssh "${SSH_OPTS[@]}" "$VPS_WG" "true" 2>/dev/null; then
  vps_state="wg"
  vps_target="$VPS_WG"
elif ssh "${SSH_OPTS[@]}" "$VPS_PUBLIC" "true" 2>/dev/null; then
  vps_state="public"
  vps_target="$VPS_PUBLIC"
fi

if [ "$vps_state" != "down" ]; then
  read -r vps_load vps_ram_used vps_ram_total vps_disk_pct conductor_inbox conductor_active < <(
    ssh "${SSH_OPTS[@]}" "$vps_target" '
      load=$(uptime | awk "{print \$(NF-2)}" | tr -d ",")
      ram_line=$(free -m | awk "/^Mem:/ {print \$3, \$2}")
      ram_used=$(echo "$ram_line" | awk "{print \$1}")
      ram_total=$(echo "$ram_line" | awk "{print \$2}")
      disk=$(df / | awk "NR==2 {print \$5}" | tr -d "%")
      inbox=$(ls /opt/conductor/queue/inbox/*.json 2>/dev/null | wc -l)
      active=$(ls /opt/conductor/queue/active/*.json 2>/dev/null | wc -l)
      echo "$load $ram_used $ram_total $disk $inbox $active"
    ' 2>/dev/null
  ) || true
fi

# ─── Auto-route hint ─────────────────────────────────
# Logic: if Mac stressed + VPS available → "vps"
# If both stressed → "wait"
# If Mac OK → "mac" (no need to delegate)
hint="mac"
mac_stressed=0
awk "BEGIN {exit !($mac_load_1 > 6)}" 2>/dev/null && mac_stressed=1
[ "$swap_pct" -gt 70 ] && mac_stressed=1
[ "$mem_pressure" -gt 0 ] && [ "$mem_pressure" -lt 40 ] && mac_stressed=1

if [ "$mac_stressed" -eq 1 ]; then
  if [ "$vps_state" = "wg" ] || [ "$vps_state" = "public" ]; then
    hint="vps"
  else
    hint="wait_or_mac_only"
  fi
fi

# ─── Snapshot ────────────────────────────────────────
snapshot=$(printf '{"ts":"%s","mac":{"load1":%s,"load5":%s,"load15":%s,"swap_used_mb":%s,"swap_total_mb":%s,"swap_pct":%s,"pressure_level":%s,"top_ram":"%s","stressed":%s},"vps":{"state":"%s","load":"%s","ram_used":"%s","ram_total":"%s","disk_pct":"%s"},"conductor":{"inbox":%s,"active":%s},"route_hint":"%s"}' \
  "$(ts)" "${mac_load_1:-0}" "${mac_load_5:-0}" "${mac_load_15:-0}" "${swap_used:-0}" "${swap_total:-0}" "${swap_pct:-0}" "${mem_pressure:-0}" "$top_ram" "$mac_stressed" \
  "$vps_state" "${vps_load:-}" "${vps_ram_used:-}" "${vps_ram_total:-}" "${vps_disk_pct:-}" \
  "${conductor_inbox:-0}" "${conductor_active:-0}" "$hint")

echo "$snapshot" >> "$LOG"

# Print compact line if interactive
if [ -t 1 ]; then
  echo "$snapshot" | python3 -c '
import json,sys
d=json.loads(sys.stdin.read())
m=d["mac"]; v=d["vps"]; c=d["conductor"]
print(f"Mac load={m[\"load1\"]}/{m[\"load5\"]}/{m[\"load15\"]} swap={m[\"swap_pct\"]}% press={m[\"pressure_level\"]} stressed={m[\"stressed\"]} | VPS state={v[\"state\"]} load={v[\"load\"]} ram={v[\"ram_used\"]}/{v[\"ram_total\"]}MB | Conductor inbox={c[\"inbox\"]} active={c[\"active\"]} | hint={d[\"route_hint\"]}")
' 2>/dev/null || echo "$snapshot"
fi

# ─── Alerting (cooldown 30 min per alert key) ────────
alert() {
  local key="$1" title="$2" msg="$3" priority="${4:-default}"
  local cooldown="$ALERT_DIR/$key"
  if [ -f "$cooldown" ]; then
    local age=$(( $(date +%s) - $(stat -f %m "$cooldown" 2>/dev/null || echo 0) ))
    [ "$age" -lt 1800 ] && return 0
  fi
  # Try VPS ntfy
  local sent=0
  if [ "$vps_state" != "down" ]; then
    local q_title q_priority
    q_title="$(shell_quote "$title")"
    q_priority="$(shell_quote "$priority")"
    # shellcheck disable=SC2029 # q_title/q_priority are locally shell-quoted before remote execution.
    ssh "${SSH_OPTS[@]}" "$vps_target" \
      "TITLE=$q_title PRIORITY=$q_priority curl -s -o /dev/null -H \"Title: \$TITLE\" -H \"Priority: \$PRIORITY\" --data-binary @- http://localhost:2586/Filip" \
      <<<"$msg" \
      2>/dev/null && sent=1 || true
  fi
  [ "$sent" -eq 0 ] && {
    osascript -e "display notification \"$msg\" with title \"$title\"" 2>/dev/null || true
  }
  touch "$cooldown"
}

# Mac swap critical
[ "$swap_pct" -gt 90 ] && alert "mac-swap-critical" "Mac swap >90%" "Mac swap $swap_pct% used. Quit Cursor/Chrome/Spotify NEBO ssh task na VPS." "high"

# Mac memory pressure critical
[ "$mem_pressure" -gt 0 ] && [ "$mem_pressure" -lt 25 ] && alert "mac-mempress-critical" "Mac memory pressure CRITICAL" "Memory pressure level $mem_pressure (<25). System swapping heavily." "urgent"

# VPS down
[ "$vps_state" = "down" ] && alert "vps-down-monitor" "VPS Flash DOWN" "Resource monitor: VPS unreachable WG+public. Recovery: $ROOT/RECOVERY-VPS-FLASH.md" "high"

# Conductor queue backlog
[ "$conductor_inbox" -gt 20 ] && alert "conductor-backlog" "Conductor queue backlog" "$conductor_inbox tasks pending in inbox. Workers may be stuck." "default"

exit 0
