#!/usr/bin/env bash
# Recovery script: resume bird (iCloud sync) + mediaanalysisd (Photos AI)
# Created 2026-05-04 17:05 by perf-tuning closure wave
# Use: bash ~/Desktop/Codex/perf-recovery.sh
set -u

echo "=== Resuming suspended system services ==="

bird_pid=$(pgrep -x bird | head -1)
media_pid=$(pgrep -fx '/System/Library/PrivateFrameworks/MediaAnalysis.framework/Versions/A/mediaanalysisd' | head -1)

if [[ -n "$bird_pid" ]]; then
  state=$(ps -p "$bird_pid" -o state= 2>/dev/null | tr -d ' ')
  if [[ "$state" == "T" ]]; then
    kill -CONT "$bird_pid" && echo "✅ bird (PID $bird_pid) RESUMED"
  else
    echo "ℹ️  bird (PID $bird_pid) already running (state=$state)"
  fi
else
  echo "⚠️  bird not found (may have respawned with new PID)"
fi

if [[ -n "$media_pid" ]]; then
  state=$(ps -p "$media_pid" -o state= 2>/dev/null | tr -d ' ')
  if [[ "$state" == "T" ]]; then
    kill -CONT "$media_pid" && echo "✅ mediaanalysisd (PID $media_pid) RESUMED"
  else
    echo "ℹ️  mediaanalysisd (PID $media_pid) already running (state=$state)"
  fi
else
  echo "⚠️  mediaanalysisd not found"
fi

echo ""
echo "=== Verify ==="
ps -p "${bird_pid:-0}","${media_pid:-0}" -o pid,state,pcpu,rss,comm 2>/dev/null || true
echo ""
echo "Done. iCloud sync + Photos AI resume v plné síle."
