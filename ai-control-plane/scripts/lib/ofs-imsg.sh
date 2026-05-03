#!/usr/bin/env bash
# ofs imsg — pošle iMessage Filipovi přes Mac Messages.app
# Self-message: target = Filipova primary Apple ID, doručí se na všechny Filipovy iDevices
# (iPhone 15, iPad, druhý Mac, atd.).
#
# Vyžaduje: macOS, Messages.app logged in jako Filip, AppleScript Automation
# perms (System Settings → Privacy & Security → Automation → Terminal/iTerm → Messages = ON).
#
# Usage:
#   ofs imsg "rychlá zpráva"
#   ofs imsg --to <other-apple-id> "zpráva"      # specific recipient
#   ofs imsg --to-phone "+420123456789" "zpráva" # send to phone (SMS fallback if iMessage off)
#
# Author: Dopita, 2026-05-03

set -euo pipefail

# Default = Filip primary Apple ID. Override via OFS_FILIP_APPLE_ID env nebo --to flag.
TARGET="${OFS_FILIP_APPLE_ID:-dlouhyphoto@gmail.com}"
SERVICE="iMessage"
TARGET_TYPE="buddy"

while [ $# -gt 0 ]; do
  case "$1" in
    --to) TARGET="$2"; shift 2 ;;
    --to-phone) TARGET="$2"; SERVICE="SMS"; shift 2 ;;
    --service) SERVICE="$2"; shift 2 ;;
    -h|--help) sed -n '2,16p' "$0" | sed 's/^# \?//'; exit 0 ;;
    *) break ;;
  esac
done

MSG="$*"

if [ -z "$MSG" ]; then
  echo "Usage: ofs imsg [--to APPLE_ID] [--to-phone +XXXXXXXXXXX] \"message\"" >&2
  exit 1
fi

# Escape pro AppleScript
MSG_ESCAPED=$(printf '%s' "$MSG" | sed 's/\\/\\\\/g; s/"/\\"/g')

osascript <<EOF
tell application "Messages"
  set targetService to first service whose service type = $SERVICE
  set targetBuddy to buddy "$TARGET" of targetService
  send "$MSG_ESCAPED" to targetBuddy
end tell
EOF

if [ $? -eq 0 ]; then
  echo "✓ iMessage sent to $TARGET: $MSG"
  ts="$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
  printf '{"ts":"%s","action":"imsg","to":"%s","msg":"%s"}\n' \
    "$ts" "$TARGET" "$(printf '%s' "$MSG" | head -c 100 | sed 's/"/\\"/g')" \
    >> "$HOME/.claude/logs/ofs.jsonl" 2>/dev/null || true
else
  echo "✗ iMessage failed. Check System Settings → Privacy → Automation → Terminal → Messages = ON" >&2
  exit 2
fi
