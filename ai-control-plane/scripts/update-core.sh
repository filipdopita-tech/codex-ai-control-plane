#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
REAL_CODE="/Applications/Visual Studio Code.app/Contents/Resources/app/bin/code"

echo "AI core update"
echo "=============="
echo

echo "1/4 Google Cloud SDK"
if command -v gcloud >/dev/null 2>&1; then
  gcloud components update --quiet || true
else
  echo "SKIP gcloud not found"
fi
echo

echo "2/4 VS Code AI/cloud extensions"
if [ -x "$REAL_CODE" ]; then
  "$REAL_CODE" --install-extension openai.chatgpt --force || true
  "$REAL_CODE" --install-extension anthropic.claude-code --force || true
  "$REAL_CODE" --install-extension GoogleCloudTools.cloudcode --force || true
else
  echo "SKIP VS Code CLI not found at $REAL_CODE"
fi
echo

echo "3/4 Homebrew full upgrade"
if command -v brew >/dev/null 2>&1; then
  brew update || true
  brew upgrade --greedy || true
  brew autoremove || true
  brew cleanup --prune=all || true
  brew outdated --greedy || true
else
  echo "SKIP brew not found"
fi
echo

echo "4/4 Doctor"
"$ROOT/ai-control-plane/scripts/doctor.sh"
