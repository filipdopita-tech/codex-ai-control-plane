#!/usr/bin/env bash
# finish-list-daily-reminder.sh — daily 9:00 push do ntfy pokud FINISH-LIST 2026-05-03 still has gaps
# Spouštěn z cron. Self-silencing: jakmile všechny WARN+FAIL = 0, sám se odhlásí (touch sentinel).

SENTINEL=/Users/filipdopita/.config/finish-list-2026-05-03.done
NTFY_URL="https://ntfy.oneflow.cz/Filip"
VERIFY=/Users/filipdopita/Desktop/Codex/ai-control-plane/scripts/verify-finish-list.sh

[[ -f "$SENTINEL" ]] && exit 0   # already closed, no reminder needed
mkdir -p "$(dirname "$SENTINEL")"

# Run quick verify (no bridge round-trip to avoid push spam)
out=$("$VERIFY" --quick 2>&1 || true)
summary=$(echo "$out" | grep -E "^PASS=" | head -1)

# Parse counts
warn=$(echo "$summary" | grep -oE "WARN=[0-9]+" | cut -d= -f2)
fail=$(echo "$summary" | grep -oE "FAIL=[0-9]+" | cut -d= -f2)

# All clear → silence
if [[ "${warn:-99}" == "0" && "${fail:-99}" == "0" ]]; then
  touch "$SENTINEL"
  curl -s -X POST -H "Title: 🟢 FINISH-LIST 2026-05-03 = DONE" -H "Tags: white_check_mark" \
    -d "Všechny gaps closed. Daily reminder cron self-silenced." "$NTFY_URL" >/dev/null
  exit 0
fi

# Surface remaining gaps to push
gaps=$(echo "$out" | grep -E "^\s*\[(WARN|FAIL)\]" | head -8 | sed 's/^[[:space:]]*//')
if [[ -z "$gaps" ]]; then
  exit 0
fi

priority="default"
[[ "${fail:-0}" -gt 0 ]] && priority="high"

curl -s -X POST -H "Title: 📋 FINISH-LIST gaps still open ($summary)" \
  -H "Priority: $priority" -H "Tags: spiral_notepad" \
  -d "$gaps

Run: ~/Desktop/Codex/ai-control-plane/scripts/verify-finish-list.sh
Detail: ~/Desktop/Codex/ai-control-plane/FINISH-LIST-2026-05-03.md" \
  "$NTFY_URL" >/dev/null
