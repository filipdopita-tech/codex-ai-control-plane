#!/usr/bin/env bash
# Performance status dashboard — single-call full state of the perf-tuning interventions
# Created 2026-05-04 17:45 Round 4 closure
# Use: bash ~/Desktop/Codex/perf-status.sh
set -u

echo "═══════════════════════════════════════════════════"
echo "  Mac Performance Status — $(date '+%Y-%m-%d %H:%M')"
echo "═══════════════════════════════════════════════════"
echo ""

echo "▸ DISK"
df -h / | tail -1 | awk '{printf "   Volume %s, %s used, %s avail (%s)\n", $1, $3, $4, $5}'
echo ""

echo "▸ MEMORY / SWAP"
sysctl vm.swapusage 2>/dev/null | awk -F'=' '{gsub(/[ \t]+/, " "); print "   "$0}'
vm_stat | awk '/Pages free|Pages active|Pages wired/ {gsub(/\./, ""); printf "   %-20s %s pages (~%d MB)\n", $1" "$2, $NF, $NF*16384/1024/1024}'
echo ""

echo "▸ SUSPENDED SYSTEM SERVICES (Round 2)"
for pid_name in "96066:bird (iCloud)" "31294:mediaanalysisd (Photos AI)"; do
  pid=${pid_name%%:*}; name=${pid_name##*:}
  if ps -p "$pid" >/dev/null 2>&1; then
    state=$(ps -p "$pid" -o state= | tr -d ' ')
    cpu=$(ps -p "$pid" -o pcpu= | tr -d ' ')
    rss=$(ps -p "$pid" -o rss= | awk '{printf "%.1f MB", $1/1024}')
    icon="✅"; [[ "$state" != "T" ]] && icon="⚠️ RUNNING"
    printf "   %s %s (PID %s) state=%s cpu=%s%% rss=%s\n" "$icon" "$name" "$pid" "$state" "$cpu" "$rss"
  else
    printf "   ⚠️ %s (PID %s) — gone (likely respawned with new PID)\n" "$name" "$pid"
  fi
done
echo "   Resume: bash ~/Desktop/Codex/perf-recovery.sh"
echo ""

echo "▸ ENV VARS (active in current session?)"
for var in BASH_DEFAULT_TIMEOUT_MS BASH_MAX_TIMEOUT_MS MCP_TIMEOUT MCP_TOOL_TIMEOUT MAX_MCP_OUTPUT_TOKENS DISABLE_NON_ESSENTIAL_MODEL_CALLS; do
  val=${!var:-NOT_SET}
  icon="✅"; [[ "$val" == "NOT_SET" ]] && icon="⚠️ pending restart"
  printf "   %s %-40s = %s\n" "$icon" "$var" "$val"
done
echo ""

echo "▸ MCP FLEET"
fleet_count=$(ps -eo args | grep -cE '(npm exec|uvx code-review|memory-search-mcp|scrapling mcp)' | head -1)
fleet_rss=$(ps -eo rss,args | grep -E '(npm exec|uvx code-review|memory-search-mcp|scrapling mcp)' | grep -v grep | awk '{sum+=$1} END {printf "%.0f MB", sum/1024}')
echo "   Procs: $fleet_count, total RSS: $fleet_rss"
claude_count=$(pgrep -fc '/opt/homebrew/bin/claude$' 2>/dev/null)
[[ -z "$claude_count" || "$claude_count" == "0" ]] && claude_count=$(ps -eo args | grep -c '/opt/homebrew/bin/claude$')
echo "   Active claude instances: $claude_count (target: 1 — close stale VS Code tabs via Cmd+W)"
echo ""

echo "▸ CACHE SIZES"
printf "   %-32s %s\n" "~/.cache/uv:" "$(du -sh ~/.cache/uv 2>/dev/null | awk '{print $1}')"
printf "   %-32s %s\n" "~/.npm:" "$(du -sh ~/.npm 2>/dev/null | awk '{print $1}')"
printf "   %-32s %s\n" "~/Library/Caches:" "$(du -sh ~/Library/Caches 2>/dev/null | awk '{print $1}')"
printf "   %-32s %s\n" "~/.claude/projects-archive:" "$(du -sh ~/.claude/projects-archive 2>/dev/null | awk '{print $1}')"
echo ""

echo "▸ TOP RAM OFFENDERS (live)"
ps -arcwwwxo pid,rss,pcpu,comm -m 2>/dev/null | head -6 | awk 'NR==1 {printf "   %-7s %-10s %-7s %s\n", $1, $2"(MB)", $3"%", $4} NR>1 {printf "   %-7s %-10.1f %-7s %s\n", $1, $2/1024, $3, $4}'
echo ""

echo "═══════════════════════════════════════════════════"
echo "  Recovery: ~/Desktop/Codex/perf-recovery.sh"
echo "  Re-tune:  ~/Desktop/Codex/perf-tune.sh"
echo "  Restart:  Cmd+Shift+P → Reload Window (Filip GUI)"
echo "═══════════════════════════════════════════════════"
