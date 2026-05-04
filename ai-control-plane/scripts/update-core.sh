#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
REAL_CODE="/Applications/Visual Studio Code.app/Contents/Resources/app/bin/code"
DRY_RUN=0
CHECK_ONLY=0

usage() {
  cat <<'EOF'
Usage: update-core.sh [--dry-run|--check-only]

Maintains the local AI control-plane core:
  - Google Cloud SDK components
  - VS Code AI/cloud extensions
  - Homebrew formulae/casks
  - final doctor report

Flags:
  --dry-run     show what would run; do not mutate system state
  --check-only  inspect update signals and run doctor; do not upgrade
  --help        show this help

Safety:
  This script never edits project files or secrets. It can update installed
  tooling unless --dry-run or --check-only is used.
EOF
}

while [ $# -gt 0 ]; do
  case "${1:-}" in
    --help|-h)
      usage
      exit 0
      ;;
    --dry-run)
      DRY_RUN=1
      shift
      ;;
    --check-only)
      CHECK_ONLY=1
      shift
      ;;
    *)
      echo "Unknown arg: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

run_step() {
  if [ "$DRY_RUN" -eq 1 ]; then
    printf 'DRY-RUN %s\n' "$*"
  else
    "$@" || true
  fi
}

echo "AI core update"
echo "=============="
echo

if [ "$DRY_RUN" -eq 1 ]; then
  echo "Mode: dry-run (no changes)"
elif [ "$CHECK_ONLY" -eq 1 ]; then
  echo "Mode: check-only (no upgrades)"
else
  echo "Mode: apply updates"
fi
echo

echo "1/4 Google Cloud SDK"
if command -v gcloud >/dev/null 2>&1; then
  if [ "$CHECK_ONLY" -eq 1 ]; then
    gcloud components list --filter='state.name:Update Available' --format='value(id)' 2>/dev/null \
      | sed 's/^/UPDATE gcloud /' || true
  else
    run_step gcloud components update --quiet
  fi
else
  echo "SKIP gcloud not found"
fi
echo

echo "2/4 VS Code AI/cloud extensions"
if [ -x "$REAL_CODE" ]; then
  if [ "$CHECK_ONLY" -eq 1 ]; then
    "$REAL_CODE" --list-extensions 2>/dev/null \
      | grep -Ei '^(openai.chatgpt|anthropic.claude-code|googlecloudtools.cloudcode)$' \
      | sort || true
  else
    run_step "$REAL_CODE" --install-extension openai.chatgpt --force
    run_step "$REAL_CODE" --install-extension anthropic.claude-code --force
    run_step "$REAL_CODE" --install-extension GoogleCloudTools.cloudcode --force
  fi
else
  echo "SKIP VS Code CLI not found at $REAL_CODE"
fi
echo

echo "3/4 Homebrew full upgrade"
if command -v brew >/dev/null 2>&1; then
  if [ "$CHECK_ONLY" -eq 1 ]; then
    brew outdated --greedy || true
  else
    run_step brew update
    run_step brew upgrade --greedy
    run_step brew autoremove
    run_step brew cleanup --prune=all
  fi
  brew outdated --greedy || true
else
  echo "SKIP brew not found"
fi
echo

echo "4/4 Doctor"
"$ROOT/ai-control-plane/scripts/doctor.sh"
