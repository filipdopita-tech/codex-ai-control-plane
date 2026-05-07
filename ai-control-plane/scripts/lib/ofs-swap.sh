#!/usr/bin/env bash
# ofs swap — Mac memory pressure relief + offload suggestions
# Detekuje nejtěžší procesy, doporučí kill / offload na VPS, optionally pause Mutagen
# Note: NO pipefail — grep -oE with no matches is normal path
set -eu

usage() {
  cat <<'EOF'
Usage: ofs swap [--auto] [--threshold PCT]

Mac memory pressure mitigation:
  1. Detect swap %, memory pressure, top RAM hogs
  2. Show actionable offload suggestions
  3. With --auto: pause Mutagen sync (řeší 1-2GB), nuke Chrome helpers nad 500MB
  4. Threshold default 70% — pod tím jen warning, nad tím akce

Anti-halucinace: real ps + sysctl + vm_stat, žádný guessing.

Příklady:
  ofs swap                       # diagnostika + suggest only
  ofs swap --auto                # auto pause Mutagen + suggest kill
  ofs swap --threshold 60 --auto
EOF
  exit "${1:-1}"
}

THRESHOLD=70
AUTO=0
while [ $# -gt 0 ]; do
  case "${1:-}" in
    --help|-h) usage 0 ;;
    --auto) AUTO=1; shift ;;
    --threshold) THRESHOLD="${2:-70}"; shift 2 ;;
    *) shift ;;
  esac
done

color() {
  case "$1" in
    bold) printf "\033[1m%s\033[0m" "$2" ;;
    red) printf "\033[31m%s\033[0m" "$2" ;;
    green) printf "\033[32m%s\033[0m" "$2" ;;
    yellow) printf "\033[33m%s\033[0m" "$2" ;;
    blue) printf "\033[34m%s\033[0m" "$2" ;;
    dim) printf "\033[2m%s\033[0m" "$2" ;;
    *) printf "%s" "$2" ;;
  esac
}

# ─── DIAGNOSTICS ────────────────────────────────────────
SWAP_LINE=$(sysctl vm.swapusage 2>/dev/null || echo "")
SWAP_TOTAL=$(printf '%s' "$SWAP_LINE" | grep -oE 'total = [0-9]+\.[0-9]+M' | grep -oE '[0-9]+\.[0-9]+' | head -1)
SWAP_USED=$(printf '%s' "$SWAP_LINE" | grep -oE 'used = [0-9]+\.[0-9]+M' | grep -oE '[0-9]+\.[0-9]+' | head -1)
SWAP_PCT=0
if [ -n "$SWAP_TOTAL" ] && [ -n "$SWAP_USED" ] && [ "$SWAP_TOTAL" != "0.00" ]; then
  SWAP_PCT=$(awk "BEGIN { printf \"%.0f\", ($SWAP_USED / $SWAP_TOTAL) * 100 }")
fi

# Memory pressure
MEM_PRESSURE_LINE=$(memory_pressure 2>/dev/null | tail -5 | head -1 || echo "")
PRESSURE_PCT=$(printf '%s' "$MEM_PRESSURE_LINE" | grep -oE '[0-9]+%' | head -1 | tr -d '%')
[ -z "$PRESSURE_PCT" ] && PRESSURE_PCT=0

LOAD=$(uptime | awk -F'load averages:' '{print $2}' | awk '{print $1}' | tr -d ',')

echo
color bold "ofs swap — Mac pressure check"; echo
echo "================================================="
echo "  Swap usage:        ${SWAP_USED:-?} / ${SWAP_TOTAL:-?} MB ($(color yellow "${SWAP_PCT}%"))"
echo "  Memory pressure:   ${PRESSURE_PCT}%"
echo "  Load (1min):       $LOAD"
echo "  Threshold:         ${THRESHOLD}%"
echo

# Top RAM hogs
echo "[Top 8 processes by RSS RAM]"
ps -axm -orss,vsz,pcpu,comm 2>/dev/null | head -1
ps -axm -orss,vsz,pcpu,comm 2>/dev/null | sort -rn | head -8
echo

# ─── DECISION ────────────────────────────────────────────
if [ "$SWAP_PCT" -lt "$THRESHOLD" ]; then
  color green "  ✓ swap ${SWAP_PCT}% pod prahem ${THRESHOLD}% — žádná akce"
  echo
  exit 0
fi

color yellow "  ⚠ swap ${SWAP_PCT}% nad prahem ${THRESHOLD}%"; echo
echo

# ─── SUGGESTIONS ────────────────────────────────────────
color blue "[Doporučené akce — od least-disruptive]"; echo
echo

echo "  1. Pause Mutagen syncs (uvolní 1-2GB inotify watchers)"
if [ "$AUTO" -eq 1 ] && command -v mutagen >/dev/null 2>&1; then
  PAUSED=$(mutagen sync list 2>/dev/null | grep -ciE 'Status: (Watching|Connected)' || echo 0)
  if [ "$PAUSED" -gt 0 ]; then
    mutagen sync pause --all 2>/dev/null && color green "     → AUTO: paused $PAUSED active session(s)" || color red "     ✗ pause failed"
    echo
  else
    color dim "     (no active sessions to pause)"; echo
  fi
else
  echo "     run: mutagen sync pause --all"
fi
echo

echo "  2. Kill Chrome helper procesy >500MB (1-3GB může jít)"
CHROME_HEAVY=$(ps -axm -orss,pid,comm 2>/dev/null | awk '$1 > 512000 && /Chrome|chrome/' | head -5)
if [ -n "$CHROME_HEAVY" ]; then
  printf '%s\n' "$CHROME_HEAVY" | while read -r rss pid comm; do
    rss_mb=$((rss / 1024))
    echo "     → PID $pid: ${rss_mb}MB ($comm)"
  done
  if [ "$AUTO" -eq 1 ]; then
    color dim "     (NOT auto-killing Chrome — risk of data loss; manual decision)"; echo
  else
    color dim "     run: kill -9 PID  (review first)"; echo
  fi
else
  color dim "     (no Chrome process >500MB)"; echo
fi
echo

echo "  3. Offload heavy work na VPS Flash"
echo "     → ofs route \"heavy/build/browser task\"  # resource-aware router"
echo "     → ofs dispatch \"task\"                   # Hermes webhook (async)"
echo "     → ssh root@10.77.0.1 'cmd'               # remote shell"
echo

echo "  4. Restart memory-greedy apps"
TOP_NON_SYSTEM=$(ps -axm -orss,pid,comm 2>/dev/null | grep -vE '(WindowServer|kernel_task|launchd|sandboxd)' | sort -rn | head -3)
if [ -n "$TOP_NON_SYSTEM" ]; then
  printf '%s\n' "$TOP_NON_SYSTEM" | while read -r rss pid comm; do
    rss_mb=$((rss / 1024))
    bn=$(basename "$comm" 2>/dev/null || echo "$comm")
    echo "     → ${bn}: ${rss_mb}MB (PID $pid)"
  done
fi
echo

echo "  5. Last resort: sudo purge (vyčistí inactive memory)"
echo "     run: sudo purge"
echo

echo "================================================="
if [ "$AUTO" -eq 1 ]; then
  color yellow "  AUTO mode: paused Mutagen, listed kills (manual approval required)"
else
  color dim "  Run with --auto to pause Mutagen automatically"
fi
echo
