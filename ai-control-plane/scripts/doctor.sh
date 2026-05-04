#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
REAL_CODE="/Applications/Visual Studio Code.app/Contents/Resources/app/bin/code"

status() {
  printf "%-6s %-28s %s\n" "$1" "$2" "${3:-}"
}

warns=0
misses=0

ok() {
  status "OK" "$1" "$2"
}

info() {
  status "INFO" "$1" "$2"
}

warn() {
  warns=$((warns + 1))
  status "WARN" "$1" "$2"
}

miss() {
  misses=$((misses + 1))
  status "MISS" "$1" "$2"
}

have() {
  command -v "$1" >/dev/null 2>&1
}

echo "AI Control Plane doctor"
echo "======================="
echo

echo "Workspace"
info "root" "$ROOT"
if [ -d "$ROOT/.git" ]; then
  ok "git workspace" "$(git -C "$ROOT" status --short --branch | sed -n '1p')"
else
  warn "git workspace" "not a git repo"
fi
echo

echo "Core CLIs"
for cmd in codex claude gcloud git rg jq node npm pnpm bun python3 brew; do
  if have "$cmd"; then
    ok "$cmd" "$(command -v "$cmd")"
  else
    miss "$cmd" "not found"
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
  ok "config.toml" "$HOME/.codex/config.toml"
  grep -E '^(model|model_reasoning_effort)|^\[mcp_servers\.|^\[plugins\.|^\[projects\.' "$HOME/.codex/config.toml" || true
else
  miss "config.toml" "$HOME/.codex/config.toml"
fi
echo

echo "Claude config"
if [ -f "$HOME/.claude/settings.json" ] && have jq; then
  ok "settings.json" "$HOME/.claude/settings.json"
  jq '{model, hooks: (.hooks|keys? // []), mcpServers: (.mcpServers|keys? // []), enabledPlugins}' "$HOME/.claude/settings.json"
else
  warn "settings.json" "missing or jq unavailable"
fi
echo

echo "VS Code"
if [ -x "$REAL_CODE" ]; then
  ok "real code CLI" "$REAL_CODE"
  "$REAL_CODE" --version 2>/dev/null | sed -n '1,3p' || true
  "$REAL_CODE" --list-extensions 2>/dev/null \
    | grep -Ei '^(openai.chatgpt|anthropic.claude-code|googlecloudtools.cloudcode|ms-vscode-remote.remote-ssh|ms-vscode-remote.remote-containers)$' \
    | sort || true
else
  miss "real code CLI" "$REAL_CODE"
fi

if have code; then
  CODE_PATH="$(command -v code)"
  ok "active code" "$CODE_PATH"
  if [ "$CODE_PATH" != "$REAL_CODE" ]; then
    info "code mode" "wrapper detected; use 'code --local' to bypass VPS routing"
  fi
fi
echo

echo "Update signals"
if have gcloud; then
  GCLOUD_ERR="$(mktemp)"
  if ! GCLOUD_UPDATES="$(gcloud components list --filter='state.name:Update Available' --format='value(id)' 2>"$GCLOUD_ERR")"; then
    warn "gcloud updates" "$(sed -n '1p' "$GCLOUD_ERR")"
  elif [ -n "$GCLOUD_UPDATES" ]; then
    warns=$((warns + 1))
    printf "%s\n" "$GCLOUD_UPDATES" | sed 's/^/UPDATE gcloud /'
  else
    ok "gcloud" "no component updates reported"
  fi
fi

if have brew; then
  BREW_ERR="$(mktemp)"
  if ! BREW_OUTDATED="$(brew outdated --greedy 2>"$BREW_ERR")"; then
    warn "brew updates" "$(sed -n '1p' "$BREW_ERR")"
  elif [ -n "$BREW_OUTDATED" ]; then
    warns=$((warns + 1))
    printf "%s\n" "$BREW_OUTDATED" | sed 's/^/UPDATE brew /'
  else
    ok "brew" "no outdated formulae/casks reported"
  fi
fi

if have npm; then
  NPM_ERR="$(mktemp)"
  if ! NPM_OUTDATED="$(npm outdated -g --depth=0 2>"$NPM_ERR")"; then
    warn "npm global" "$(sed -n '1p' "$NPM_ERR")"
  elif [ -n "$NPM_OUTDATED" ]; then
    warns=$((warns + 1))
    printf "%s\n" "$NPM_OUTDATED" | sed 's/^/UPDATE npm /'
  else
    ok "npm global" "no outdated packages reported"
  fi
fi

echo
echo "Ecosystem audit"
AUDIT_OUT="$(mktemp)"
if "$ROOT/ai-control-plane/scripts/ecosystem-audit.sh" > "$AUDIT_OUT" 2>&1; then
  cat "$AUDIT_OUT"
  if grep -q '^WARN   audit summary' "$AUDIT_OUT"; then
    warns=$((warns + 1))
  fi
else
  cat "$AUDIT_OUT"
  misses=$((misses + 1))
fi

echo
echo "Doctor summary"
if [ "$misses" -gt 0 ]; then
  status "MISS" "doctor summary" "$misses missing core item(s), $warns warning signal(s)"
  exit 1
elif [ "$warns" -gt 0 ]; then
  status "WARN" "doctor summary" "$warns warning signal(s), no missing core items"
else
  status "OK" "doctor summary" "clean"
fi
