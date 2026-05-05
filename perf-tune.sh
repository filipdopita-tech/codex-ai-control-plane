#!/usr/bin/env bash
# Performance tune — repeatable performance interventions on stressed Mac
# Combines Round 2 (SIGSTOP services) + Round 3-4 (cache prune)
# Created 2026-05-04 17:45 Round 4 closure
# Use: bash ~/Desktop/Codex/perf-tune.sh
set -u

echo "═══════════════════════════════════════════════════"
echo "  Mac Performance Tune — $(date '+%Y-%m-%d %H:%M')"
echo "═══════════════════════════════════════════════════"
echo ""

# ── Round 2: Suspend heavy system services ──
echo "▸ Suspending heavy services (reversible via perf-recovery.sh)"

bird_pid=$(pgrep -x bird | head -1)
if [[ -n "$bird_pid" ]]; then
  state=$(ps -p "$bird_pid" -o state= | tr -d ' ')
  if [[ "$state" != "T" ]]; then
    kill -STOP "$bird_pid" && echo "   ✅ bird (PID $bird_pid) suspended"
  else
    echo "   ℹ️  bird already suspended"
  fi
fi

media_pid=$(pgrep -fx '/System/Library/PrivateFrameworks/MediaAnalysis.framework/Versions/A/mediaanalysisd' | head -1)
if [[ -n "$media_pid" ]]; then
  state=$(ps -p "$media_pid" -o state= | tr -d ' ')
  if [[ "$state" != "T" ]]; then
    kill -STOP "$media_pid" && echo "   ✅ mediaanalysisd (PID $media_pid) suspended"
  else
    echo "   ℹ️  mediaanalysisd already suspended"
  fi
fi
echo ""

# ── Round 3: Cache cleanups ──
echo "▸ Cache prune"

# npm
START_NPM=$(du -sk ~/.npm 2>/dev/null | awk '{print $1}')
npm cache clean --force >/dev/null 2>&1
END_NPM=$(du -sk ~/.npm 2>/dev/null | awk '{print $1}')
echo "   ✅ npm: $((START_NPM/1024)) MB → $((END_NPM/1024)) MB (-$(((START_NPM-END_NPM)/1024)) MB)"

# VS Code VSIX
VSIX=~/Library/Application\ Support/Code/CachedExtensionVSIXs
if [[ -d "$VSIX" ]]; then
  START_VSIX=$(du -sk "$VSIX" 2>/dev/null | awk '{print $1}')
  rm -rf "$VSIX"/* 2>/dev/null
  END_VSIX=$(du -sk "$VSIX" 2>/dev/null | awk '{print $1}')
  echo "   ✅ VSIX cache: $((START_VSIX/1024)) MB → $((END_VSIX/1024)) MB"
fi

# uv (force, even if locked by active MCPs)
START_UV=$(du -sk ~/.cache/uv 2>/dev/null | awk '{print $1}')
UV_LOCK_TIMEOUT=10 uv cache prune --force 2>&1 | tail -1
END_UV=$(du -sk ~/.cache/uv 2>/dev/null | awk '{print $1}')
echo "   ✅ uv: $((START_UV/1024)) MB → $((END_UV/1024)) MB (-$(((START_UV-END_UV)/1024)) MB)"

# Brew
brew cleanup -s >/dev/null 2>&1 && echo "   ✅ brew cleaned"
echo ""

echo "▸ State after tune"
df -h / | tail -1 | awk '{printf "   Disk: %s avail of %s\n", $4, $2}'
sysctl vm.swapusage 2>/dev/null | awk -F'=' '{gsub(/[ \t]+/, " "); print "   "$0}'
echo ""

echo "═══════════════════════════════════════════════════"
echo "  Status:   ~/Desktop/Codex/perf-status.sh"
echo "  Recovery: ~/Desktop/Codex/perf-recovery.sh"
echo "═══════════════════════════════════════════════════"
