#!/usr/bin/env bash
# codex-usage-live.sh - live Codex subscription usage from the open Safari Analytics tab.
#
# Reads the already-authenticated ChatGPT/Codex Analytics page via Safari AppleScript.
# No tokens or cookies are printed. Default mode is a one-shot snapshot.
#
# Usage:
#   ./ai-control-plane/scripts/codex-usage-live.sh             # one snapshot
#   ./ai-control-plane/scripts/codex-usage-live.sh --live      # refresh every 15s
#   ./ai-control-plane/scripts/codex-usage-live.sh --live 5    # refresh every 5s

set -uo pipefail

URL="https://chatgpt.com/codex/cloud/settings/analytics#usage"
INTERVAL="${2:-15}"
ONCE=0
LIVE=0

if [ "${1:-}" = "--live" ]; then
  LIVE=1
elif [ "${1:-}" = "" ] || [ "${1:-}" = "--once" ]; then
  ONCE=1
  INTERVAL=0
else
  echo "Usage: $0 [--once|--live [seconds]]" >&2
  exit 2
fi

if ! [[ "$INTERVAL" =~ ^[0-9]+$ ]]; then
  echo "Usage: $0 [--once|--live [seconds]]" >&2
  exit 2
fi

fetch_text() {
  osascript <<'APPLESCRIPT'
tell application "Safari"
  repeat with w in windows
    repeat with t in tabs of w
      set tabUrl to URL of t
      if tabUrl contains "chatgpt.com/codex" and tabUrl contains "analytics" then
        return do JavaScript "document.body.innerText" in t
      end if
    end repeat
  end repeat
end tell
return ""
APPLESCRIPT
}

value_after_label() {
  awk -v label="$1" '
    $0 == label { found = 1; next }
    found && $0 ~ /^[0-9]+%$/ { print $0; exit }
  '
}

reset_after_label() {
  awk -v label="$1" '
    $0 == label { found = 1; next }
    found && /^Resets / { sub(/^Resets /, ""); print; exit }
  '
}

first_credit_balance() {
  awk '
    $0 == "Credits remaining" { found = 1; next }
    found && $0 ~ /^[0-9]+([.][0-9]+)?$/ { print $0; exit }
  '
}

bar() {
  local percent="$1"
  percent="${percent%%%}"
  local width=24
  local filled=$((percent * width / 100))
  local empty=$((width - filled))
  local i
  printf "["
  for ((i = 0; i < filled; i++)); do printf "#"; done
  for ((i = 0; i < empty; i++)); do printf "-"; done
  printf "]"
}

render_once() {
  local text
  text="$(fetch_text)"

  if [ -z "$text" ]; then
    echo "Codex Analytics tab not found in Safari."
    echo "Open: $URL"
    echo "Safari must allow JavaScript from Apple Events: Safari > Develop > Allow JavaScript from Apple Events."
    return 1
  fi

  local five weekly spark_five spark_weekly credits five_reset weekly_reset
  five="$(printf "%s\n" "$text" | value_after_label "5 hour usage limit")"
  weekly="$(printf "%s\n" "$text" | value_after_label "Weekly usage limit")"
  spark_five="$(printf "%s\n" "$text" | value_after_label "GPT-5.3-Codex-Spark 5 hour usage limit")"
  spark_weekly="$(printf "%s\n" "$text" | value_after_label "GPT-5.3-Codex-Spark Weekly usage limit")"
  credits="$(printf "%s\n" "$text" | first_credit_balance)"
  five_reset="$(printf "%s\n" "$text" | reset_after_label "5 hour usage limit")"
  weekly_reset="$(printf "%s\n" "$text" | reset_after_label "Weekly usage limit")"

  five="${five:-unknown}"
  weekly="${weekly:-unknown}"
  spark_five="${spark_five:-unknown}"
  spark_weekly="${spark_weekly:-unknown}"
  credits="${credits:-unknown}"

  if [ "$LIVE" -eq 1 ]; then
    printf "Codex usage live - %s\n" "$(date '+%Y-%m-%d %H:%M:%S')"
  else
    printf "Codex usage snapshot - %s\n" "$(date '+%Y-%m-%d %H:%M:%S')"
  fi
  printf "Source: Safari Codex Analytics\n\n"

  if [[ "$five" =~ ^[0-9]+%$ ]]; then
    printf "Main 5h:     %4s remaining %s" "$five" "$(bar "$five")"
    [ -n "${five_reset:-}" ] && printf " resets %s" "$five_reset"
    printf "\n"
  else
    printf "Main 5h:     %s\n" "$five"
  fi

  if [[ "$weekly" =~ ^[0-9]+%$ ]]; then
    printf "Main weekly: %4s remaining %s" "$weekly" "$(bar "$weekly")"
    [ -n "${weekly_reset:-}" ] && printf " resets %s" "$weekly_reset"
    printf "\n"
  else
    printf "Main weekly: %s\n" "$weekly"
  fi

  if [[ "$spark_five" =~ ^[0-9]+%$ ]]; then
    printf "Spark 5h:    %4s remaining %s\n" "$spark_five" "$(bar "$spark_five")"
  else
    printf "Spark 5h:    %s\n" "$spark_five"
  fi

  if [[ "$spark_weekly" =~ ^[0-9]+%$ ]]; then
    printf "Spark week:  %4s remaining %s\n" "$spark_weekly" "$(bar "$spark_weekly")"
  else
    printf "Spark week:  %s\n" "$spark_weekly"
  fi

  printf "Credits:     %s\n" "$credits"
}

if [ "$ONCE" -eq 1 ] || [ "$LIVE" -eq 0 ]; then
  render_once
  exit $?
fi

while true; do
  clear
  render_once || true
  printf "\nRefresh: %ss | Ctrl-C to stop\n" "$INTERVAL"
  sleep "$INTERVAL"
done
