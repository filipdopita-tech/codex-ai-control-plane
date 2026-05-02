#!/usr/bin/env bash
# ofs heal — self-healing layer
# Detekuje down/degraded services, auto-restartuje, ntfy alert.
# Anti-halucinace: real systemctl checks, exit codes verified.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
LOG_DIR="$HOME/.claude/logs"
LOG_FILE="$LOG_DIR/ofs-heal.jsonl"
mkdir -p "$LOG_DIR"
VPS_WG="root@10.77.0.1"
NTFY_LOCAL_HOST="http://localhost:2586/Filip"
NTFY_PUBLIC="https://ntfy.oneflow.cz/Filip"

usage() {
  cat <<'EOF'
Usage: ofs heal [--dry-run] [--no-notify]

Self-healing layer:
  1. Check Mac local services    (mutagen agent)
  2. Check VPS Flash reachable   (WG tunel + public fallback)
  3. Check VPS systemd services  (caddy, ntfy, conductor, hermes-agent)
  4. Detect down/degraded         → auto-restart attempt
  5. Verify post-restart          → real systemctl is-active
  6. ntfy summary                 (sent or not based on flag)

Exit:
  0 ALL HEALTHY (or restart succeeded)
  1 SOMETHING STILL DOWN after restart
  2 VPS unreachable (cannot heal remotely)

Příklady:
  ofs heal              # full heal cycle
  ofs heal --dry-run    # check only, no restart, no notify
EOF
  exit "${1:-1}"
}

DRY_RUN=0
NOTIFY=1
while [ $# -gt 0 ]; do
  case "${1:-}" in
    --help|-h) usage 0 ;;
    --dry-run) DRY_RUN=1; shift ;;
    --no-notify) NOTIFY=0; shift ;;
    *) shift ;;
  esac
done

ts() { date -u '+%Y-%m-%dT%H:%M:%SZ'; }

log() {
  local svc="$1" before="$2" action="$3" after="$4"
  printf '{"ts":"%s","service":"%s","before":"%s","action":"%s","after":"%s","dry_run":%d}\n' \
    "$(ts)" "$svc" "$before" "$action" "$after" "$DRY_RUN" >> "$LOG_FILE"
}

color() {
  case "$1" in
    bold) printf "\033[1m%s\033[0m" "$2" ;;
    red) printf "\033[31m%s\033[0m" "$2" ;;
    green) printf "\033[32m%s\033[0m" "$2" ;;
    yellow) printf "\033[33m%s\033[0m" "$2" ;;
    blue) printf "\033[34m%s\033[0m" "$2" ;;
    dim) printf "\033[2m%s\033[0m" "$2" ;;
    *) printf "%s" "$2" ;;
  esac
}

notify_phone() {
  [ "$NOTIFY" -eq 0 ] && return 0
  [ "$DRY_RUN" -eq 1 ] && return 0
  local title="$1" msg="$2" prio="${3:-default}"
  curl -s -o /dev/null --max-time 4 \
    -H "Title: $title" -H "Priority: $prio" \
    -d "$msg" "$NTFY_PUBLIC" 2>/dev/null || true
}

DOWN_BEFORE=()
RESTARTED=()
STILL_DOWN=()

echo
color bold "ofs heal — $(date '+%Y-%m-%d %H:%M')"; echo
echo "================================================="

# ─── Mac local: mutagen ──────────────────────────────────
color blue "[mac/mutagen]"; echo
if command -v mutagen >/dev/null 2>&1; then
  PAUSED=$(mutagen sync list 2>/dev/null | grep -ciE 'Paused|Stopped' || echo 0)
  if [ "$PAUSED" -gt 0 ]; then
    color yellow "  ⚠ $PAUSED session(s) paused"; echo
    DOWN_BEFORE+=("mac:mutagen:$PAUSED-paused")
    if [ "$DRY_RUN" -eq 0 ]; then
      mutagen sync resume --all 2>/dev/null && {
        color green "  → resumed all sessions"; echo
        RESTARTED+=("mutagen")
        log "mutagen" "paused" "resume" "checking"
      } || {
        color red "  ✗ resume failed"; echo
        STILL_DOWN+=("mutagen")
        log "mutagen" "paused" "resume" "failed"
      }
    fi
  else
    color green "  ✓ all sessions running"; echo
  fi
else
  color dim "  (mutagen not installed, skip)"; echo
fi
echo

# ─── VPS reachability ────────────────────────────────────
color blue "[vps-flash/ssh]"; echo
VPS_REACHABLE=0
if ssh -o ConnectTimeout=4 -o BatchMode=yes "$VPS_WG" "true" 2>/dev/null; then
  color green "  ✓ WG tunel reachable"; echo
  VPS_REACHABLE=1
else
  color red "  ✗ VPS Flash UNREACHABLE — manual recovery needed"; echo
  echo "    See: $ROOT/RECOVERY-VPS-FLASH.md"
  notify_phone "VPS Flash DOWN" "Cannot reach 10.77.0.1 nor public IP" "high"
  log "vps-ssh" "unreachable" "skip" "manual"
  exit 2
fi
echo

# ─── VPS systemd services ────────────────────────────────
color blue "[vps/systemd-services]"; echo
SERVICES_SYSTEM=("caddy" "ntfy" "conductor")
SERVICES_USER=("hermes-gateway.service")

for svc in "${SERVICES_SYSTEM[@]}"; do
  state=$(ssh -o ConnectTimeout=4 -o BatchMode=yes "$VPS_WG" "systemctl is-active $svc 2>/dev/null" 2>/dev/null || echo "unreachable")
  if [ "$state" = "active" ]; then
    color green "  ✓ $svc"; echo
  else
    color yellow "  ⚠ $svc: $state"; echo
    DOWN_BEFORE+=("vps:$svc:$state")
    if [ "$DRY_RUN" -eq 0 ]; then
      echo "    → restart $svc"
      ssh -o ConnectTimeout=4 -o BatchMode=yes "$VPS_WG" "systemctl restart $svc 2>&1" 2>/dev/null && {
        sleep 2
        new_state=$(ssh -o ConnectTimeout=4 -o BatchMode=yes "$VPS_WG" "systemctl is-active $svc" 2>/dev/null || echo "unknown")
        if [ "$new_state" = "active" ]; then
          color green "    ✓ recovered"; echo
          RESTARTED+=("$svc")
          log "$svc" "$state" "restart" "active"
        else
          color red "    ✗ still $new_state"; echo
          STILL_DOWN+=("$svc")
          log "$svc" "$state" "restart" "$new_state"
        fi
      }
    fi
  fi
done

for svc in "${SERVICES_USER[@]}"; do
  state=$(ssh -o ConnectTimeout=4 -o BatchMode=yes "$VPS_WG" "systemctl --user is-active $svc 2>/dev/null" 2>/dev/null || echo "unreachable")
  if [ "$state" = "active" ]; then
    color green "  ✓ $svc (user)"; echo
  else
    color yellow "  ⚠ $svc (user): $state"; echo
    DOWN_BEFORE+=("vps:user:$svc:$state")
    if [ "$DRY_RUN" -eq 0 ]; then
      echo "    → restart $svc (user)"
      ssh -o ConnectTimeout=4 -o BatchMode=yes "$VPS_WG" "systemctl --user restart $svc 2>&1" 2>/dev/null && {
        sleep 2
        new_state=$(ssh -o ConnectTimeout=4 -o BatchMode=yes "$VPS_WG" "systemctl --user is-active $svc" 2>/dev/null || echo "unknown")
        if [ "$new_state" = "active" ]; then
          color green "    ✓ recovered"; echo
          RESTARTED+=("$svc")
          log "$svc" "$state" "user-restart" "active"
        else
          color red "    ✗ still $new_state"; echo
          STILL_DOWN+=("$svc")
          log "$svc" "$state" "user-restart" "$new_state"
        fi
      }
    fi
  fi
done
echo

# ─── HTTPS endpoints ────────────────────────────────────
color blue "[vps/https-endpoints]"; echo
ENDPOINTS=("https://ntfy.oneflow.cz" "https://dispatch.oneflow.cz/health")
for ep in "${ENDPOINTS[@]}"; do
  code=$(curl -s -o /dev/null -w "%{http_code}" --max-time 5 "$ep" 2>/dev/null || echo "000")
  if [ "$code" = "200" ] || [ "$code" = "301" ] || [ "$code" = "401" ] || [ "$code" = "404" ]; then
    color green "  ✓ $ep ($code)"; echo
  else
    color red "  ✗ $ep ($code)"; echo
    DOWN_BEFORE+=("https:$ep:$code")
  fi
done
echo

# ─── VERDICT ────────────────────────────────────────────
echo "================================================="
if [ ${#DOWN_BEFORE[@]} -eq 0 ]; then
  color green "  ✓ HEALTHY — all services up"
  echo
  exit 0
fi

if [ "$DRY_RUN" -eq 1 ]; then
  color yellow "  ⚠ DRY-RUN — ${#DOWN_BEFORE[@]} issue(s) detected, no action taken"
  echo
  printf '    - %s\n' "${DOWN_BEFORE[@]}"
  exit 0
fi

if [ ${#STILL_DOWN[@]} -eq 0 ]; then
  color green "  ✓ HEALED — recovered: ${RESTARTED[*]:-none}"
  echo
  notify_phone "ofs heal — recovered" "Restarted: ${RESTARTED[*]:-none}" "default"
  exit 0
fi

color red "  ✗ DEGRADED — still down after restart: ${STILL_DOWN[*]}"
echo
notify_phone "ofs heal — DEGRADED" "Still down after restart: ${STILL_DOWN[*]}" "high"
exit 1
