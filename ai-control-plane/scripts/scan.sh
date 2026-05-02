#!/usr/bin/env bash
set -euo pipefail

if [ "${1:-}" = "--help" ] || [ "${1:-}" = "-h" ]; then
  cat <<'EOF'
Usage: scan.sh

Lightweight discovery scan: core CLIs, Codex/Claude config snapshot,
and Mac/Documents+Desktop projects with .git/.claude/.codex markers.

Doesn't modify anything. For full diagnostics use doctor.sh.
EOF
  exit 0
fi

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

echo "AI Control Plane scan"
echo "====================="
echo

echo "Workspace: $ROOT"
echo

echo "Core commands:"
for cmd in codex claude code git rg jq node npm python3; do
  if command -v "$cmd" >/dev/null 2>&1; then
    printf "OK   %-8s %s\n" "$cmd" "$(command -v "$cmd")"
  else
    printf "MISS %-8s not found\n" "$cmd"
  fi
done

echo
echo "Codex config:"
if [ -f "$HOME/.codex/config.toml" ]; then
  grep -E '^(model|model_reasoning_effort)|^\[mcp_servers\.|^\[plugins\.|^\[projects\.' "$HOME/.codex/config.toml" || true
else
  echo "Missing ~/.codex/config.toml"
fi

echo
echo "Claude config summary:"
if [ -f "$HOME/.claude/settings.json" ] && command -v jq >/dev/null 2>&1; then
  jq '{model, hooks: (.hooks|keys? // []), mcpServers: (.mcpServers|keys? // []), enabledPlugins}' "$HOME/.claude/settings.json"
else
  echo "Missing ~/.claude/settings.json or jq"
fi

echo
echo "Projects with AI config:"
find "$HOME/Documents" "$HOME/Desktop" -maxdepth 2 -type d \( -name .git -o -name .claude -o -name .codex \) 2>/dev/null | sed 's#/.git$# [git]#; s#/.claude$# [claude]#; s#/.codex$# [codex]#' | sort | sed -n '1,220p'

