#!/usr/bin/env bash
# check-flash-auth — auth expiry detector pro Flash claude-rc service.
# Spouští se přes cron každých 6h NA FLASH. Když detekuje expiry/login=false →
# ntfy push Filipovi: "Flash auth expired, run `ofs mobile-flash from-mac` na Macu".
#
# Deploy:
#   scp check-flash-auth.sh root@10.77.0.1:/usr/local/bin/
#   ssh root@10.77.0.1 'chmod +x /usr/local/bin/check-flash-auth.sh'
#   ssh root@10.77.0.1 'echo "0 */6 * * * root /usr/local/bin/check-flash-auth.sh" > /etc/cron.d/claude-flash-auth-check'
#
# Manual run:
#   /usr/local/bin/check-flash-auth.sh           # silent if OK, ntfy if FAIL
#   /usr/local/bin/check-flash-auth.sh --verbose # also echo status
#
# Author: Dopita, 2026-05-03

set -euo pipefail

VERBOSE=0
FORCE_NTFY=0
for a in "$@"; do
  case "$a" in
    --verbose|-v) VERBOSE=1 ;;
    --force-ntfy) FORCE_NTFY=1 ;;
  esac
done

LOG="/var/log/claude-flash-auth-check.log"
NTFY_LOCAL="http://localhost:2586/Filip"
NTFY_PUBLIC="https://ntfy.oneflow.cz/Filip"

ts() { date -u '+%Y-%m-%dT%H:%M:%SZ'; }
log() { printf '[%s] %s\n' "$(ts)" "$*" >> "$LOG" 2>/dev/null || true; }

# Try claude auth status (JSON output)
AUTH_RAW="$(claude auth status 2>/dev/null || echo '{}')"
LOGGED_IN="$(echo "$AUTH_RAW" | grep -oE '"loggedIn":[[:space:]]*(true|false)' | grep -oE '(true|false)' || echo 'unknown')"
EMAIL="$(echo "$AUTH_RAW" | grep -oE '"email":[[:space:]]*"[^"]+"' | sed 's/.*"\(.*\)"/\1/' || echo 'unknown')"
ORG="$(echo "$AUTH_RAW" | grep -oE '"orgName":[[:space:]]*"[^"]+"' | sed 's/.*"\(.*\)"/\1/' || echo 'unknown')"

# Service health
SVC_STATE="$(systemctl is-active claude-rc 2>/dev/null || echo 'unknown')"

# Token expiry estimate (rough — based on credentials.json mtime + typical 30-90 day TTL)
CREDS_FILE="/root/.claude/.credentials.json"
if [ -f "$CREDS_FILE" ]; then
  AGE_DAYS="$(( ( $(date +%s) - $(stat -c %Y "$CREDS_FILE" 2>/dev/null || echo 0) ) / 86400 ))"
else
  AGE_DAYS="?"
fi

STATUS_LINE="auth=$LOGGED_IN email=$EMAIL service=$SVC_STATE creds_age=${AGE_DAYS}d"

[ "$VERBOSE" -eq 1 ] && echo "$STATUS_LINE"
log "$STATUS_LINE"

# Decision
ALERT=0
ALERT_MSG=""

if [ "$LOGGED_IN" != "true" ]; then
  ALERT=1
  ALERT_MSG="Flash auth EXPIRED (loggedIn=$LOGGED_IN). Run on Mac: ofs mobile-flash from-mac"
elif [ "$SVC_STATE" != "active" ]; then
  ALERT=1
  ALERT_MSG="Flash claude-rc service is $SVC_STATE (not active). Check: ofs mobile-flash logs"
elif [ "$AGE_DAYS" != "?" ] && [ "$AGE_DAYS" -gt 60 ]; then
  ALERT=1
  ALERT_MSG="Flash creds are ${AGE_DAYS}d old (typical OAuth expiry ~30-90d). Pre-emptive: ofs mobile-flash from-mac"
fi

if [ "$ALERT" -eq 1 ] || [ "$FORCE_NTFY" -eq 1 ]; then
  log "ALERT: $ALERT_MSG"
  # Try local ntfy first, fallback to public
  curl -s -o /dev/null --max-time 5 \
    -H "Title: Flash Auth Check" \
    -H "Priority: high" \
    -H "Tags: warning,key" \
    -d "$ALERT_MSG (status: $STATUS_LINE)" \
    "$NTFY_LOCAL" 2>/dev/null \
    || curl -s -o /dev/null --max-time 5 \
       -H "Title: Flash Auth Check" \
       -H "Priority: high" \
       -H "Tags: warning,key" \
       -d "$ALERT_MSG (status: $STATUS_LINE)" \
       "$NTFY_PUBLIC" 2>/dev/null \
    || log "ntfy push FAILED (both local + public)"
  [ "$VERBOSE" -eq 1 ] && echo "ALERT sent: $ALERT_MSG"
  exit 1
fi

[ "$VERBOSE" -eq 1 ] && echo "OK — auth healthy"
exit 0
