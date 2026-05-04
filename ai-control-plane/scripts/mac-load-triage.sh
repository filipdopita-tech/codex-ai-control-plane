#!/usr/bin/env bash
set -euo pipefail

echo "Mac load triage"
echo "==============="
echo

echo "Load:"
uptime
echo

echo "Swap:"
if sysctl vm.swapusage >/dev/null 2>&1; then
  sysctl vm.swapusage
else
  echo "swapusage unavailable"
fi
echo

echo "Memory pressure:"
if command -v memory_pressure >/dev/null 2>&1; then
  memory_pressure | sed -n '1,18p'
else
  sysctl -n kern.memorystatus_level 2>/dev/null || true
fi
echo

echo "Top CPU processes:"
ps auxw 2>/dev/null \
  | sort -k3 -rn \
  | awk 'BEGIN {printf "%-12s %6s %6s %s\n", "USER", "%CPU", "%MEM", "COMMAND"}
         $1 == "USER" {next}
         shown < 15 {cmd=$11; for (i=12; i<=NF; i++) cmd=cmd" "$i; printf "%-12s %6s %6s %.140s\n", $1, $3, $4, cmd; shown++}' \
  || true
echo

echo "Top RAM processes:"
ps auxw 2>/dev/null \
  | sort -k4 -rn \
  | awk 'BEGIN {printf "%-12s %6s %6s %s\n", "USER", "%CPU", "%MEM", "COMMAND"}
         $1 == "USER" {next}
         shown < 15 {cmd=$11; for (i=12; i<=NF; i++) cmd=cmd" "$i; printf "%-12s %6s %6s %.140s\n", $1, $3, $4, cmd; shown++}' \
  || true
echo

echo "Latest resource route hint:"
if [ -f "$HOME/.claude/logs/resource-monitor.jsonl" ] && command -v jq >/dev/null 2>&1; then
  tail -1 "$HOME/.claude/logs/resource-monitor.jsonl" \
    | jq '{ts, mac: {load1: .mac.load1, swap_pct: .mac.swap_pct, pressure_level: .mac.pressure_level, stressed: .mac.stressed, top_ram: .mac.top_ram}, vps: .vps, route_hint}'
else
  echo "No resource monitor log found."
fi
echo

cat <<'EOF'
Operating guidance:
- swap >= 90%: prefer VPS/offload for heavy Claude/Codex/browser work.
- route_hint = vps: delegate long-running jobs rather than stacking local agents.
- keep local work to narrow edits/checks until swap drops below 80%.
EOF
