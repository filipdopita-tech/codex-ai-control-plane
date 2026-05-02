#!/usr/bin/env bash
set -u

REAL_CODE="/Applications/Visual Studio Code.app/Contents/Resources/app/bin/code"

echo "AI ecosystem healthcheck"
echo "========================="
echo

echo "Workspace:"
pwd
echo

echo "Shell:"
echo "${SHELL:-unknown}"
echo

echo "PATH:"
echo "$PATH"
echo

check_command() {
  local name="$1"
  if command -v "$name" >/dev/null 2>&1; then
    printf "OK   %-10s %s\n" "$name" "$(command -v "$name")"
  else
    printf "MISS %-10s not found\n" "$name"
  fi
}

echo "Commands:"
check_command date
check_command find
check_command git
check_command jq
check_command code
check_command rg
check_command claude
check_command codex
check_command gcloud
check_command node
check_command npm
check_command pnpm
check_command bun
check_command python3
echo

echo "Versions:"
date 2>/dev/null || true
git --version 2>/dev/null || true
node --version 2>/dev/null || true
npm --version 2>/dev/null || true
pnpm --version 2>/dev/null || true
bun --version 2>/dev/null || true
python3 --version 2>/dev/null || true
claude --version 2>/dev/null || true
codex --version 2>/dev/null || true
gcloud --version 2>/dev/null | sed -n '1,8p' || true

echo
echo "VS Code / Cloud Code:"
if [ -x "$REAL_CODE" ]; then
  "$REAL_CODE" --version 2>/dev/null | sed -n '1,3p' || true
  "$REAL_CODE" --list-extensions 2>/dev/null \
    | grep -Ei '^(openai.chatgpt|anthropic.claude-code|googlecloudtools.cloudcode|ms-vscode-remote.remote-ssh|ms-vscode-remote.remote-containers)$' \
    | sort || true
else
  echo "MISS real VS Code CLI: $REAL_CODE"
fi

if command -v code >/dev/null 2>&1; then
  CODE_PATH="$(command -v code)"
  echo "code wrapper: $CODE_PATH"
  if [ "$CODE_PATH" != "$REAL_CODE" ]; then
    echo "note: 'code' is a wrapper; use code --local for local VS Code when needed."
  fi
fi

echo
echo "Google Cloud updates:"
if command -v gcloud >/dev/null 2>&1; then
  gcloud components list --filter='state.name:Update Available' --format='value(id)' 2>/dev/null \
    | sed 's/^/UPDATE /' || true
else
  echo "MISS gcloud"
fi
