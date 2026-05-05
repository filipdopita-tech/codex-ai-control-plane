#!/usr/bin/env bash
# Post-restart prune — spustit PO restartu Claude Code session
# Důvod: uv cache (5 GB) je při běžící session locknutý code-review-graph
# a memory-search-mcp MCPs. Po restartu lock release → můžeme pruneovat.
# Created: 2026-05-04 17:30 Round 3 closure
# Use: bash ~/Desktop/Codex/perf-postrestart-prune.sh

set -u

echo "=== Post-restart cache prune ==="
date '+%Y-%m-%d %H:%M:%S'

START_UV=$(du -sk ~/.cache/uv 2>/dev/null | awk '{print $1}')
echo "uv cache before: $((START_UV/1024)) MB"
echo ""

echo "→ uv cache prune (unused entries)..."
if uv cache prune 2>&1 | tail -3; then
  END_UV=$(du -sk ~/.cache/uv 2>/dev/null | awk '{print $1}')
  echo "✅ uv cache: $((START_UV/1024)) MB → $((END_UV/1024)) MB (saved $(((START_UV-END_UV)/1024)) MB)"
else
  echo "⚠️ uv cache prune failed — may still be locked. Check active uv processes."
fi
echo ""

echo "→ Verify env vars activated (need restart to confirm):"
echo "   BASH_DEFAULT_TIMEOUT_MS=300000 (5 min)"
echo "   BASH_MAX_TIMEOUT_MS=900000 (15 min)"
echo "   MCP_TIMEOUT=60000 (60s startup)"
echo "   MCP_TOOL_TIMEOUT=60000 (60s per call)"
echo "   MAX_MCP_OUTPUT_TOKENS=50000"
echo "   DISABLE_NON_ESSENTIAL_MODEL_CALLS=1"
echo ""
echo "Inside fresh Claude session, verify:"
echo "   echo \$BASH_DEFAULT_TIMEOUT_MS  → expect 300000"
echo ""

echo "→ Doctor.sh delta:"
cd ~/Desktop/Codex 2>/dev/null && bash ai-control-plane/scripts/doctor.sh 2>&1 | grep -E "(MCP process count|Mac resource)"

echo ""
echo "Done."
