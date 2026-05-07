#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
DEST="$HOME/.claude/scripts/oneflow-ecosystem"

mkdir -p "$DEST"

for script in \
  update-extended.sh \
  resource-monitor.sh \
  security-audit.sh \
  obsidian-dashboard.sh \
  usage-tracker.sh
do
  install -m 755 "$ROOT/ai-control-plane/scripts/$script" "$DEST/$script"
  xattr -c "$DEST/$script" 2>/dev/null || true
  echo "synced $script"
done

echo "Runtime scripts synced to $DEST"
