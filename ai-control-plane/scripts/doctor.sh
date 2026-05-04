#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
REAL_CODE="/Applications/Visual Studio Code.app/Contents/Resources/app/bin/code"

status() {
  printf "%-6s %-28s %s\n" "$1" "$2" "${3:-}"
}

have() {
  command -v "$1" >/dev/null 2>&1
}

echo "AI Control Plane doctor"
echo "======================="
echo

echo "Workspace"
status "INFO" "root" "$ROOT"
if [ -d "$ROOT/.git" ]; then
  status "OK" "git workspace" "$(git -C "$ROOT" status --short --branch | sed -n '1p')"
else
  status "WARN" "git workspace" "not a git repo"
fi
echo

echo "Core CLIs"
for cmd in codex claude gcloud git rg jq node npm pnpm bun python3 brew; do
  if have "$cmd"; then
    status "OK" "$cmd" "$(command -v "$cmd")"
  else
    status "MISS" "$cmd" "not found"
  fi
done
echo

echo "Versions"
codex --version 2>/dev/null || true
claude --version 2>/dev/null || true
gcloud --version 2>/dev/null | sed -n '1,4p' || true
node --version 2>/dev/null || true
npm --version 2>/dev/null || true
pnpm --version 2>/dev/null || true
bun --version 2>/dev/null || true
python3 --version 2>/dev/null || true
echo

echo "Codex config"
if [ -f "$HOME/.codex/config.toml" ]; then
  status "OK" "config.toml" "$HOME/.codex/config.toml"
  grep -E '^(model|model_reasoning_effort)|^\[mcp_servers\.|^\[plugins\.|^\[projects\.' "$HOME/.codex/config.toml" || true
else
  status "MISS" "config.toml" "$HOME/.codex/config.toml"
fi
echo

echo "Claude config"
if [ -f "$HOME/.claude/settings.json" ] && have jq; then
  status "OK" "settings.json" "$HOME/.claude/settings.json"
  jq '{model, hooks: (.hooks|keys? // []), mcpServers: (.mcpServers|keys? // []), enabledPlugins}' "$HOME/.claude/settings.json"
else
  status "WARN" "settings.json" "missing or jq unavailable"
fi
echo

echo "VS Code"
if [ -x "$REAL_CODE" ]; then
  status "OK" "real code CLI" "$REAL_CODE"
  "$REAL_CODE" --version 2>/dev/null | sed -n '1,3p' || true
  "$REAL_CODE" --list-extensions 2>/dev/null \
    | grep -Ei '^(openai.chatgpt|anthropic.claude-code|googlecloudtools.cloudcode|ms-vscode-remote.remote-ssh|ms-vscode-remote.remote-containers)$' \
    | sort || true
else
  status "MISS" "real code CLI" "$REAL_CODE"
fi

if have code; then
  CODE_PATH="$(command -v code)"
  status "OK" "active code" "$CODE_PATH"
  if [ "$CODE_PATH" != "$REAL_CODE" ]; then
    status "INFO" "code mode" "wrapper detected; use 'code --local' to bypass VPS routing"
  fi
fi
echo

echo "Update signals"
if have gcloud; then
  GCLOUD_ERR="$(mktemp)"
  if ! GCLOUD_UPDATES="$(gcloud components list --filter='state.name:Update Available' --format='value(id)' 2>"$GCLOUD_ERR")"; then
    status "WARN" "gcloud updates" "$(sed -n '1p' "$GCLOUD_ERR")"
  elif [ -n "$GCLOUD_UPDATES" ]; then
    printf "%s\n" "$GCLOUD_UPDATES" | sed 's/^/UPDATE gcloud /'
  else
    status "OK" "gcloud" "no component updates reported"
  fi
fi

if have brew; then
  BREW_ERR="$(mktemp)"
  if ! BREW_OUTDATED="$(brew outdated --greedy 2>"$BREW_ERR")"; then
    status "WARN" "brew updates" "$(sed -n '1p' "$BREW_ERR")"
  elif [ -n "$BREW_OUTDATED" ]; then
    printf "%s\n" "$BREW_OUTDATED" | sed 's/^/UPDATE brew /'
  else
    status "OK" "brew" "no outdated formulae/casks reported"
  fi
fi

if have npm; then
  NPM_ERR="$(mktemp)"
  if ! NPM_OUTDATED="$(npm outdated -g --depth=0 2>"$NPM_ERR")"; then
    status "WARN" "npm global" "$(sed -n '1p' "$NPM_ERR")"
  elif [ -n "$NPM_OUTDATED" ]; then
    printf "%s\n" "$NPM_OUTDATED" | sed 's/^/UPDATE npm /'
  else
    status "OK" "npm global" "no outdated packages reported"
  fi
fi

echo
echo "Ecosystem audit"
"$ROOT/ai-control-plane/scripts/ecosystem-audit.sh" || true
