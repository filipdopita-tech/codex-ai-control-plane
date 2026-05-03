#!/usr/bin/env bash
# ofs pushcut — Claude → Filip's iPhone přes Pushcut webhook
#
# Pushcut umožňuje:
#   - Push notification s custom title/subtitle/sound
#   - Trigger iOS Shortcut (Personal Automation)
#   - Open URL na iPhone
#   - Speak text (audio)
#   - Vibrate
#
# Setup (jednou, viz iPhone-SETUP.md):
#   1. Install Pushcut iOS app + login
#   2. Settings → API → copy API key + webhook URL
#   3. Save do ~/.credentials/pushcut.env (chmod 600):
#      PUSHCUT_API_KEY=...
#      PUSHCUT_WEBHOOK_URL=https://api.pushcut.io/v1/notifications/{NOTIF_NAME}
#
# Usage:
#   ofs pushcut "Title" "Subtitle"
#   ofs pushcut --speak "Mluvený text v češtině"
#   ofs pushcut --url "https://claude.ai/code"
#   ofs pushcut --shortcut "ShortcutName"
#
# Author: Dopita, 2026-05-03

set -euo pipefail

CREDS="${PUSHCUT_CREDS:-$HOME/.credentials/pushcut.env}"
[ -f "$CREDS" ] && source "$CREDS"

if [ -z "${PUSHCUT_API_KEY:-}" ] || [ -z "${PUSHCUT_WEBHOOK_URL:-}" ]; then
  cat <<EOF >&2
ERR: Pushcut creds not configured.

Setup:
  1. Install Pushcut iOS (https://apps.apple.com/app/pushcut/id1471477085)
  2. App → Settings → API → copy "API Key" + "Webhook URL"
  3. Save (chmod 600):
     mkdir -p ~/.credentials
     cat > ~/.credentials/pushcut.env <<CREDS
     PUSHCUT_API_KEY=...
     PUSHCUT_WEBHOOK_URL=https://api.pushcut.io/v1/notifications/...
     CREDS
     chmod 600 ~/.credentials/pushcut.env

  4. Re-run: ofs pushcut "test" "from claude"

Detail: ai-control-plane/iPhone-SETUP.md
EOF
  exit 2
fi

mode="notif"
text=""
url=""
shortcut=""
title="Claude"
subtitle=""

while [ $# -gt 0 ]; do
  case "$1" in
    --speak)    mode="speak"; text="$2"; shift 2 ;;
    --url)      mode="url"; url="$2"; shift 2 ;;
    --shortcut) mode="shortcut"; shortcut="$2"; shift 2 ;;
    --title)    title="$2"; shift 2 ;;
    -h|--help)  sed -n '2,21p' "$0" | sed 's/^# \?//'; exit 0 ;;
    *)
      if [ -z "$title" ] || [ "$title" = "Claude" ]; then
        title="$1"
      else
        subtitle="${subtitle:+$subtitle }$1"
      fi
      shift ;;
  esac
done

build_payload() {
  case "$mode" in
    speak)
      printf '{"text":%s,"sound":"vibrate","speak":true}' \
        "$(printf '%s' "$text" | python3 -c 'import json,sys; print(json.dumps(sys.stdin.read()))')"
      ;;
    url)
      printf '{"title":%s,"text":"Open URL","url":%s}' \
        "$(printf '%s' "$title" | python3 -c 'import json,sys; print(json.dumps(sys.stdin.read()))')" \
        "$(printf '%s' "$url" | python3 -c 'import json,sys; print(json.dumps(sys.stdin.read()))')"
      ;;
    shortcut)
      printf '{"title":%s,"text":"Triggering shortcut","actions":[{"shortcut":%s}]}' \
        "$(printf '%s' "$title" | python3 -c 'import json,sys; print(json.dumps(sys.stdin.read()))')" \
        "$(printf '%s' "$shortcut" | python3 -c 'import json,sys; print(json.dumps(sys.stdin.read()))')"
      ;;
    *)
      printf '{"title":%s,"text":%s}' \
        "$(printf '%s' "$title" | python3 -c 'import json,sys; print(json.dumps(sys.stdin.read()))')" \
        "$(printf '%s' "$subtitle" | python3 -c 'import json,sys; print(json.dumps(sys.stdin.read()))')"
      ;;
  esac
}

payload="$(build_payload)"

resp="$(curl -s -X POST "$PUSHCUT_WEBHOOK_URL" \
  -H "Content-Type: application/json" \
  -H "API-Key: $PUSHCUT_API_KEY" \
  -d "$payload" \
  -w "\n___CODE=%{http_code}" --max-time 10)"
code="$(echo "$resp" | grep -oE '___CODE=[0-9]+' | cut -d= -f2)"

if [ "$code" = "200" ] || [ "$code" = "204" ]; then
  echo "✓ Pushcut sent ($mode): $title"
else
  echo "✗ Pushcut failed (HTTP $code)" >&2
  echo "$resp" | grep -v ___CODE | head -3
  exit 3
fi

# Audit log
ts="$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
printf '{"ts":"%s","action":"pushcut","mode":"%s","title":"%s"}\n' \
  "$ts" "$mode" "$(printf '%s' "$title" | head -c 80)" \
  >> "$HOME/.claude/logs/ofs.jsonl" 2>/dev/null || true
