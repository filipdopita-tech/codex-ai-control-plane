#!/usr/bin/env bash
set -euo pipefail

CLAUDE_DIR="${CLAUDE_DIR:-$HOME/.claude}"
SETTINGS="$CLAUDE_DIR/settings.json"

if [[ ! -f "$SETTINGS" ]]; then
  echo "ERROR: missing $SETTINGS" >&2
  exit 1
fi

if ! command -v jq >/dev/null 2>&1; then
  echo "ERROR: jq is required" >&2
  exit 1
fi

ts="$(date +%Y%m%d-%H%M%S)"
backup="$SETTINGS.context-repair-$ts.bak"
tmp="$(mktemp)"

cp "$SETTINGS" "$backup"

jq '
  .model = "claude-opus-4-7"
  | .effortLevel = "xhigh"
  | .env.MAX_THINKING_TOKENS = "32000"
  | .env.CLAUDE_CODE_EFFORT_LEVEL = "xhigh"
  | .env.CLAUDE_AUTOCOMPACT_PCT_OVERRIDE = "60"
  | .env.CLAUDE_CODE_ENABLE_AWAY_SUMMARY = "0"
  | .hooks = {
      "PreToolUse": [
        {
          "matcher": "Bash",
          "hooks": [
            {
              "type": "command",
              "command": "bash $HOME/.claude/hooks/google-api-guard.sh",
              "timeout": 5
            },
            {
              "type": "command",
              "command": "bash $HOME/.claude/hooks/anti-deletion.sh",
              "timeout": 5
            },
            {
              "type": "command",
              "command": "bash $HOME/.claude/hooks/gitleaks-guard.sh",
              "timeout": 10
            }
          ]
        },
        {
          "matcher": "Write|Edit",
          "hooks": [
            {
              "type": "command",
              "command": "bash $HOME/.claude/hooks/security-guard.sh",
              "timeout": 5
            },
            {
              "type": "command",
              "command": "bash $HOME/.claude/hooks/memory-secret-scan.sh",
              "timeout": 5
            }
          ]
        }
      ]
    }
' "$SETTINGS" > "$tmp"

jq empty "$tmp"
mv "$tmp" "$SETTINGS"
chmod 600 "$SETTINGS" "$backup"

echo "Claude Code context repair applied."
echo "Backup: $backup"
echo
echo "Current summary:"
jq '{model, effortLevel, env: {MAX_THINKING_TOKENS: .env.MAX_THINKING_TOKENS, CLAUDE_CODE_EFFORT_LEVEL: .env.CLAUDE_CODE_EFFORT_LEVEL, CLAUDE_AUTOCOMPACT_PCT_OVERRIDE: .env.CLAUDE_AUTOCOMPACT_PCT_OVERRIDE, CLAUDE_CODE_ENABLE_AWAY_SUMMARY: .env.CLAUDE_CODE_ENABLE_AWAY_SUMMARY}, hooks: (.hooks|keys)}' "$SETTINGS"
