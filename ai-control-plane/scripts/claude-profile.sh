#!/usr/bin/env bash
set -euo pipefail

CLAUDE_DIR="${CLAUDE_DIR:-$HOME/.claude}"
SETTINGS="$CLAUDE_DIR/settings.json"

usage() {
  cat <<'USAGE'
Usage: claude-profile.sh <lean|power|debug|show>

Profiles:
  lean   Stable daily default. Sonnet, medium effort, early compact, only safety hooks.
  power  More autonomous execution. Keeps context-expanding hooks off, raises thinking.
  debug  Conservative troubleshooting. Sonnet, low effort, lowest context growth.
  show   Print current profile-relevant settings.

Every write creates a timestamped backup next to settings.json.
USAGE
}

profile="${1:-show}"

if [ ! -f "$SETTINGS" ]; then
  echo "ERROR: missing $SETTINGS" >&2
  exit 1
fi

if ! command -v jq >/dev/null 2>&1; then
  echo "ERROR: jq is required" >&2
  exit 1
fi

show_profile() {
  jq '{
    model,
    env: {
      CLAUDE_CODE_EFFORT_LEVEL: .env.CLAUDE_CODE_EFFORT_LEVEL,
      MAX_THINKING_TOKENS: .env.MAX_THINKING_TOKENS,
      CLAUDE_AUTOCOMPACT_PCT_OVERRIDE: .env.CLAUDE_AUTOCOMPACT_PCT_OVERRIDE,
      CLAUDE_CODE_ENABLE_AWAY_SUMMARY: .env.CLAUDE_CODE_ENABLE_AWAY_SUMMARY,
      CLAUDE_CODE_SUBAGENT_MODEL: .env.CLAUDE_CODE_SUBAGENT_MODEL,
      CLAUDE_CODE_ENABLE_TOOL_SEARCH: .env.CLAUDE_CODE_ENABLE_TOOL_SEARCH
    },
    hooks: (.hooks | keys),
    permissions: {
      defaultMode: .permissions.defaultMode,
      allowCount: ((.permissions.allow // []) | length)
    },
    mcpServers: ((.mcpServers // {}) | keys | length),
    enabledPlugins: ((.enabledPlugins // {}) | keys | length)
  }' "$SETTINGS"
}

safety_hooks='{
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
}'

case "$profile" in
  show)
    show_profile
    exit 0
    ;;
  lean|power|debug)
    ;;
  -h|--help)
    usage
    exit 0
    ;;
  *)
    echo "ERROR: unknown profile: $profile" >&2
    usage >&2
    exit 2
    ;;
esac

ts="$(date +%Y%m%d-%H%M%S)"
backup="$SETTINGS.profile-$profile-$ts.bak"
tmp="$(mktemp)"
cp "$SETTINGS" "$backup"

case "$profile" in
  lean)
    jq --argjson hooks "$safety_hooks" '
      .model = "sonnet"
      | .env.MAX_THINKING_TOKENS = "8000"
      | .env.CLAUDE_CODE_EFFORT_LEVEL = "medium"
      | .env.CLAUDE_AUTOCOMPACT_PCT_OVERRIDE = "60"
      | .env.CLAUDE_CODE_ENABLE_AWAY_SUMMARY = "0"
      | .env.CLAUDE_CODE_SUBAGENT_MODEL = "haiku"
      | .hooks = $hooks
    ' "$SETTINGS" > "$tmp"
    ;;
  power)
    jq --argjson hooks "$safety_hooks" '
      .model = "sonnet"
      | .env.MAX_THINKING_TOKENS = "16000"
      | .env.CLAUDE_CODE_EFFORT_LEVEL = "high"
      | .env.CLAUDE_AUTOCOMPACT_PCT_OVERRIDE = "65"
      | .env.CLAUDE_CODE_ENABLE_AWAY_SUMMARY = "0"
      | .env.CLAUDE_CODE_SUBAGENT_MODEL = "haiku"
      | .hooks = $hooks
    ' "$SETTINGS" > "$tmp"
    ;;
  debug)
    jq --argjson hooks "$safety_hooks" '
      .model = "sonnet"
      | .env.MAX_THINKING_TOKENS = "4000"
      | .env.CLAUDE_CODE_EFFORT_LEVEL = "low"
      | .env.CLAUDE_AUTOCOMPACT_PCT_OVERRIDE = "50"
      | .env.CLAUDE_CODE_ENABLE_AWAY_SUMMARY = "0"
      | .env.CLAUDE_CODE_SUBAGENT_MODEL = "haiku"
      | .hooks = $hooks
    ' "$SETTINGS" > "$tmp"
    ;;
esac

jq empty "$tmp"
mv "$tmp" "$SETTINGS"
chmod 600 "$SETTINGS" "$backup"

echo "Claude profile applied: $profile"
echo "Backup: $backup"
echo
show_profile
