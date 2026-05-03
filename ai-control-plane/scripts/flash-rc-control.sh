#!/usr/bin/env bash
# flash-rc-control — kontrola Flash RC service z Macu
# Wrapped via `ofs mobile-flash <subcommand>`.
#
# Subcommands:
#   status     systemctl is-active + journal tail
#   logs       tail /var/log/claude-rc.log
#   restart    systemctl restart claude-rc
#   stop       systemctl stop claude-rc + disable
#   start      systemctl start claude-rc
#   reauth     re-run flash-rc-setup.sh --reauth
#   url        zkus extrahovat session URL z logu pro reconnect
#   sync-ecosystem  mirror Mac ~/.claude/{rules,knowledge,...} → Flash /root/.claude-ecosystem
#   check-auth      detect OAuth expiry + ntfy alert (cron-friendly)
#   ecosystem-info  show /root/.claude-ecosystem manifest + last sync ts
#
# Author: Dopita, 2026-05-03

set -euo pipefail

VPS="root@10.77.0.1"
SVC="claude-rc"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

cmd="${1:-status}"
shift || true

vps_check() {
  ssh -o ConnectTimeout=5 -o BatchMode=yes "$VPS" "true" 2>/dev/null \
    || { echo "ERR: VPS Flash unreachable"; exit 2; }
}

case "$cmd" in
  status|s)
    vps_check
    state="$(ssh "$VPS" "systemctl is-active $SVC")"
    enabled="$(ssh "$VPS" "systemctl is-enabled $SVC 2>/dev/null" || echo '?')"
    pid="$(ssh "$VPS" "systemctl show $SVC -p MainPID --value 2>/dev/null")"
    uptime="$(ssh "$VPS" "systemctl show $SVC -p ActiveEnterTimestamp --value 2>/dev/null" || echo '?')"
    auth="$(ssh "$VPS" "claude auth status 2>/dev/null | grep -oE '\"loggedIn\":[[:space:]]*(true|false)'" || echo 'unknown')"

    printf "Service:    %s (enabled=%s)\n" "$state" "$enabled"
    printf "PID:        %s\n" "$pid"
    printf "Active since: %s\n" "$uptime"
    printf "Auth:       %s\n" "$auth"
    echo "---"
    ssh "$VPS" "tail -8 /var/log/claude-rc.log 2>/dev/null" || echo "(no log yet)"
    ;;

  logs|log|l)
    vps_check
    n="${1:-50}"
    ssh "$VPS" "tail -$n /var/log/claude-rc.log 2>/dev/null" \
      || echo "(no log)"
    ;;

  follow|f)
    vps_check
    ssh -t "$VPS" "tail -f /var/log/claude-rc.log"
    ;;

  restart|r)
    vps_check
    ssh "$VPS" "systemctl restart $SVC"
    sleep 3
    ssh "$VPS" "systemctl is-active $SVC"
    ;;

  stop)
    vps_check
    ssh "$VPS" "systemctl stop $SVC && systemctl disable $SVC 2>&1 | grep -v Removed || true"
    echo "Stopped + disabled. Re-enable: ofs mobile-flash start"
    ;;

  start)
    vps_check
    ssh "$VPS" "systemctl enable --now $SVC 2>&1 | grep -v Created || true"
    sleep 3
    ssh "$VPS" "systemctl is-active $SVC"
    ;;

  reauth)
    bash "$SCRIPT_DIR/flash-rc-setup.sh" --reauth
    ;;

  from-mac|sync-mac)
    bash "$SCRIPT_DIR/flash-rc-setup.sh" --from-mac
    ;;

  list-accounts|accounts)
    vps_check
    echo "Available accounts (in /root/.claude/creds-backup/):"
    ssh "$VPS" "cd /root/.claude/creds-backup 2>/dev/null && for f in *.json; do
      [ -e \"\$f\" ] || continue
      name=\${f%.json}
      org=\$(python3 -c \"import json; print(json.load(open('\$f')).get('organizationUuid','?'))\" 2>/dev/null)
      printf '  %-20s  org=%s\n' \"\$name\" \"\$org\"
    done"
    echo ""
    echo "Currently active:"
    ssh "$VPS" "claude auth status 2>/dev/null | grep -E 'email|orgName' | head -2"
    ;;

  use)
    vps_check
    name="${1:-}"
    if [ -z "$name" ]; then
      echo "Usage: ofs mobile-flash use <account-name>"
      echo "       ofs mobile-flash list-accounts   # show available"
      exit 1
    fi
    creds="/root/.claude/creds-backup/${name}.json"
    cache="/root/.claude/creds-backup/${name}.oauth.json"
    if ! ssh "$VPS" "[ -f $creds ] && [ -f $cache ]" 2>/dev/null; then
      echo "ERR: backup not found (creds + oauth cache): $name"
      echo "Save current state as backup: ofs mobile-flash save-as $name"
      exit 2
    fi
    ssh "$VPS" "
      systemctl stop claude-rc
      cp $creds /root/.claude/.credentials.json && chmod 600 /root/.claude/.credentials.json
      python3 -c \"
import json, os
oauth = json.load(open('$cache'))
d = json.load(open('/root/.claude.json'))
d['oauthAccount'] = oauth
json.dump(d, open('/root/.claude.json','w'), indent=2)
os.chmod('/root/.claude.json', 0o600)
\"
      truncate -s 0 /var/log/claude-rc.log
      systemctl restart claude-rc
    "
    sleep 8
    echo "Switched to: $name"
    ssh "$VPS" "claude auth status 2>/dev/null | grep -E 'email|orgName' | head -2"
    ssh "$VPS" "systemctl is-active claude-rc"
    ;;

  save-as)
    vps_check
    name="${1:-}"
    if [ -z "$name" ]; then
      echo "Usage: ofs mobile-flash save-as <account-name>"
      echo "(Saves current Flash creds + oauthAccount cache as backup)"
      exit 1
    fi
    ssh "$VPS" "
      mkdir -p /root/.claude/creds-backup && chmod 700 /root/.claude/creds-backup
      cp /root/.claude/.credentials.json /root/.claude/creds-backup/${name}.json
      python3 -c \"
import json
d = json.load(open('/root/.claude.json'))
oauth = d.get('oauthAccount', {})
import json as j
j.dump(oauth, open('/root/.claude/creds-backup/${name}.oauth.json','w'), indent=2)
\"
      chmod 600 /root/.claude/creds-backup/${name}.json /root/.claude/creds-backup/${name}.oauth.json
    "
    echo "Saved as: $name (creds + oauth cache)"
    ssh "$VPS" "ls -la /root/.claude/creds-backup/${name}*"
    ;;

  url)
    vps_check
    # Extract environment URL from log (format: https://claude.ai/code?environment=env_XXXX)
    url="$(ssh "$VPS" "grep -oE 'https://claude\.ai/code\?environment=env_[A-Za-z0-9]+' /var/log/claude-rc.log 2>/dev/null | tail -1" || echo '')"
    if [ -n "$url" ]; then
      echo "Session URL: $url"
      echo "(Otevři v browseru pro web access NEBO najdi 'Filip Flash' v Claude iOS app session list)"
    else
      echo "Žádná URL v logu. Service je možná čerstvě restartovaný — počkej 10s a zkus znovu."
      echo "Nebo zkontroluj: ofs mobile-flash logs"
    fi
    ;;

  qr)
    # Server mode CLI emit QR jen interaktivně (po stisku spacebar). Pro headless setup:
    # session se najde v iOS app session list pod jménem "Filip Flash".
    cat <<'EOF'
Pro QR scan: server mode systemd nemá interaktivní spacebar trigger.
Ale session "Filip Flash" se objeví v Claude iOS app session list automaticky:

  1. Otevři Claude app na iPhone
  2. Login stejným Anthropic Max účtem
  3. Najdi "Filip Flash" v session list (computer ikona, zelená tečka)
  4. Tap → connected

Pokud session URL potřebuješ explicitně (browser access):
  ofs mobile-flash url
EOF
    ;;

  sync-ecosystem|sync)
    bash "$SCRIPT_DIR/sync-ecosystem-to-flash.sh" "$@"
    ;;

  ecosystem-info|eco-info|info)
    vps_check
    ssh "$VPS" "[ -f /root/.claude-ecosystem/MANIFEST.md ] && cat /root/.claude-ecosystem/MANIFEST.md || echo '(no manifest — run: ofs mobile-flash sync-ecosystem)'"
    ;;

  check-auth|auth-check|ca)
    vps_check
    ssh "$VPS" "/usr/local/bin/check-flash-auth.sh ${1:-}" 2>/dev/null \
      || ssh "$VPS" "claude auth status 2>&1 | head -8"
    ;;

  -h|--help|help)
    sed -n '2,18p' "$0" | sed 's/^# \?//'
    ;;

  *)
    echo "Unknown: $cmd"
    sed -n '2,18p' "$0" | sed 's/^# \?//'
    exit 1
    ;;
esac
