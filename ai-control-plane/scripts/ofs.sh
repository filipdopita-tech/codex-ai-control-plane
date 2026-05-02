#!/usr/bin/env bash
# ofs — OneFlow System dispatcher
# Single entry point pro Mac+VPS+phone ekosystém.
# Wraps existing route-task.sh + delegate-to-codex.sh + ask-claude-* + mac/vps status.
#
# Filip rules respected:
#  - VPS-first (vždy preferuj VPS pokud running)
#  - Anti-halucinace (status = real check, ne predict)
#  - Token efficiency (compact output, no preamble)
#  - Security (no eval, validated paths, audit log)
#  - Hard-stop zone (žádné platby/odeslání/destrukce/FB-login bez explicit)
#
# Author: Dopita, 2026-05-02

set -euo pipefail

# ─── CONFIG ────────────────────────────────────────────────────────────
# Follow symlink (ofs is symlinked from ~/.local/bin/ofs)
_OFS_SCRIPT="${BASH_SOURCE[0]}"
while [ -L "$_OFS_SCRIPT" ]; do
  _OFS_TARGET="$(readlink "$_OFS_SCRIPT")"
  case "$_OFS_TARGET" in
    /*) _OFS_SCRIPT="$_OFS_TARGET" ;;
    *)  _OFS_SCRIPT="$(dirname "$_OFS_SCRIPT")/$_OFS_TARGET" ;;
  esac
done
ROOT="$(cd "$(dirname "$_OFS_SCRIPT")/.." && pwd)"  # ai-control-plane root
WORKSPACE_DEFAULT="$(cd "$ROOT/.." && pwd)"          # Codex root
LOG_DIR="$HOME/.claude/logs"
LOG_FILE="$LOG_DIR/ofs.jsonl"
VPS_WG="root@10.77.0.1"
VPS_PUBLIC="root@173.212.220.67"
NTFY_LOCAL="http://localhost:2586/Filip"
NTFY_PUBLIC="https://ntfy.oneflow.cz/Filip"
NTFY_FALLBACK="https://ntfy.sh/oneflow-filip-direct"

mkdir -p "$LOG_DIR"

# ─── HELPERS ───────────────────────────────────────────────────────────
ts() { date -u '+%Y-%m-%dT%H:%M:%SZ'; }

log() {
  # Audit log (security: žádná secrets v promptu)
  local action="$1" status="$2" detail="${3:-}"
  printf '{"ts":"%s","action":"%s","status":"%s","detail":"%s"}\n' \
    "$(ts)" "$action" "$status" "$(printf '%s' "$detail" | head -c 200 | sed 's/"/\\"/g')" \
    >> "$LOG_FILE"
}

color() {
  case "$1" in
    red)    printf "\033[31m%s\033[0m" "$2" ;;
    green)  printf "\033[32m%s\033[0m" "$2" ;;
    yellow) printf "\033[33m%s\033[0m" "$2" ;;
    blue)   printf "\033[34m%s\033[0m" "$2" ;;
    bold)   printf "\033[1m%s\033[0m" "$2" ;;
    *) printf "%s" "$2" ;;
  esac
}

# Notify — try local VPS ntfy, fallback to public ntfy.oneflow.cz, finally macOS native
notify() {
  local title="$1" msg="$2" priority="${3:-default}"
  local sent=0
  if command -v ssh >/dev/null && ssh -o ConnectTimeout=3 -o BatchMode=yes "$VPS_WG" "true" 2>/dev/null; then
    ssh -o ConnectTimeout=3 -o BatchMode=yes "$VPS_WG" \
      "curl -s -o /dev/null -H 'Title: $title' -H 'Priority: $priority' -d '$msg' $NTFY_LOCAL" \
      && sent=1
  fi
  if [ "$sent" -eq 0 ]; then
    curl -s -o /dev/null --max-time 5 \
      -H "Title: $title" -H "Priority: $priority" \
      -d "$msg" "$NTFY_PUBLIC" 2>/dev/null && sent=1 || true
  fi
  if [ "$sent" -eq 0 ]; then
    osascript -e "display notification \"$msg\" with title \"$title\"" 2>/dev/null || true
  fi
}

# VPS reachable? Echoes state ("wg"/"public"/"down"), always returns 0
# (caller checks the echoed string, not exit code — avoids set -e issues)
vps_status() {
  if ssh -o ConnectTimeout=4 -o BatchMode=yes "$VPS_WG" "true" 2>/dev/null; then
    echo "wg"
  elif ssh -o ConnectTimeout=4 -o BatchMode=yes "$VPS_PUBLIC" "true" 2>/dev/null; then
    echo "public"
  else
    echo "down"
  fi
  return 0
}

# Mac load metrics
mac_load() {
  # Triple metrics: load avg, swap %, free RAM
  local load avg5 swap_total swap_used swap_pct mem_pressure
  load=$(uptime | awk -F'load averages:' '{print $2}' | awk '{print $1}' | tr -d ',')
  avg5=$(uptime | awk -F'load averages:' '{print $2}' | awk '{print $2}' | tr -d ',')
  if sysctl vm.swapusage 2>/dev/null | grep -q total; then
    swap_total=$(sysctl vm.swapusage | grep -oE 'total = [0-9]+\.[0-9]+M' | grep -oE '[0-9]+\.[0-9]+')
    swap_used=$(sysctl vm.swapusage | grep -oE 'used = [0-9]+\.[0-9]+M' | grep -oE '[0-9]+\.[0-9]+')
    swap_pct=$(awk "BEGIN {printf \"%.0f\", ($swap_used / $swap_total) * 100}")
  else
    swap_total=0; swap_used=0; swap_pct=0
  fi
  mem_pressure=$(sysctl -n kern.memorystatus_level 2>/dev/null || echo 0)
  printf "%s|%s|%s|%s|%s|%s" "$load" "$avg5" "$swap_used" "$swap_total" "$swap_pct" "$mem_pressure"
}

# Validate project path (security: prevent directory traversal)
validate_project() {
  local p="$1"
  if [ ! -d "$p" ]; then
    color red "ERROR: project path does not exist: $p" >&2
    echo >&2
    return 2
  fi
  # Resolve and check it's not /, /etc, /System
  local abs
  abs="$(cd "$p" && pwd)"
  case "$abs" in
    /|/etc|/etc/*|/System|/System/*|/usr|/usr/*)
      color red "ERROR: refused unsafe project path: $abs" >&2
      echo >&2
      return 3
      ;;
  esac
}

# ─── COMMANDS ──────────────────────────────────────────────────────────

cmd_status() {
  set +o pipefail  # status command should not crash on benign pipe closure
  echo
  color bold "OneFlow System Status"; echo
  echo "===================="
  echo
  # VPS
  printf "  VPS Flash:   "
  local v
  v=$(vps_status)
  case "$v" in
    wg)     color green "✓ UP (WG tunel 10.77.0.1)"; echo ;;
    public) color yellow "⚠ UP (public IP only, WG down)"; echo ;;
    down)   color red "✗ DOWN — recovery: $ROOT/RECOVERY-VPS-FLASH.md"; echo ;;
  esac

  # Mac load
  IFS='|' read -r load avg5 swap_used swap_total swap_pct mem_pressure < <(mac_load) || true
  local load_color="green"
  awk "BEGIN {exit !($load > 8)}" && load_color="red"
  awk "BEGIN {exit !($load > 5 && $load <= 8)}" && load_color="yellow"
  printf "  Mac load:    "
  color "$load_color" "$load (5min: $avg5)"
  echo

  local swap_color="green"
  [ "$swap_pct" -gt 80 ] && swap_color="red"
  [ "$swap_pct" -gt 50 ] && [ "$swap_pct" -le 80 ] && swap_color="yellow"
  printf "  Mac swap:    "
  color "$swap_color" "$swap_pct% ($swap_used / $swap_total MB)"
  echo
  printf "  Mac memory pressure level: "
  if [ "$mem_pressure" -gt 60 ]; then color green "OK ($mem_pressure)"
  elif [ "$mem_pressure" -gt 30 ]; then color yellow "WARN ($mem_pressure)"
  else color red "CRITICAL ($mem_pressure)"
  fi
  echo

  # Mutagen
  if command -v mutagen >/dev/null 2>&1; then
    local m_active m_paused
    m_active=$(mutagen sync list 2>/dev/null | grep -cE 'Status:.*Watching|Status:.*Connected' 2>/dev/null | head -1)
    m_paused=$(mutagen sync list 2>/dev/null | grep -cE 'Status:.*Paused' 2>/dev/null | head -1)
    m_active=${m_active:-0}
    m_paused=${m_paused:-0}
    printf "  Mutagen:     "
    if [ "$m_active" -gt 0 ] 2>/dev/null; then
      color green "$m_active active"
      [ "$m_paused" -gt 0 ] && { printf ", "; color yellow "$m_paused paused"; }
      echo
    else
      color yellow "$m_paused paused (waiting on VPS)"; echo
    fi
  fi

  # AI CLIs
  printf "  Claude CLI:  "
  claude --version 2>/dev/null | head -1 || color red "missing"
  echo
  printf "  Codex CLI:   "
  codex --version 2>/dev/null | head -1 || color red "missing"
  echo
  printf "  VS Code:     "
  code --version 2>/dev/null | head -1 || color red "missing"
  echo

  # Recent handoffs
  echo
  color bold "  Recent handoffs (last 3):"; echo
  ls -1t "$ROOT/handoffs/"*.md 2>/dev/null | head -3 | while read -r f; do
    local fname mtime
    fname="$(basename "$f")"
    mtime="$(stat -f '%Sm' -t '%Y-%m-%d %H:%M' "$f" 2>/dev/null)"
    echo "    $mtime — $fname"
  done

  echo
  log "status" "ok" ""
}

cmd_route() {
  local project task
  if [ "${1:-}" = "--here" ]; then
    project="$WORKSPACE_DEFAULT"
    shift
  elif [ -d "${1:-}" ]; then
    project="$1"
    shift
  else
    project="$WORKSPACE_DEFAULT"
  fi
  task="$*"
  [ -z "$task" ] && { color red "Usage: ofs route [project_path] \"task\""; echo; exit 1; }
  validate_project "$project"
  log "route" "start" "$task"
  "$ROOT/scripts/route-task.sh" "$project" "$task"
}

cmd_delegate() {
  local project task mode="${OFS_CODEX_MODE:-auto}"
  if [ "${1:-}" = "--here" ]; then
    project="$WORKSPACE_DEFAULT"; shift
  elif [ -d "${1:-}" ]; then
    project="$1"; shift
  else
    project="$WORKSPACE_DEFAULT"
  fi
  task="$*"
  [ -z "$task" ] && { color red "Usage: ofs delegate [project_path] \"task\""; echo; exit 1; }
  validate_project "$project"
  log "delegate" "start" "$task"
  AI_BRIDGE_CODEX_MODE="$mode" "$ROOT/scripts/delegate-to-codex.sh" "$project" "$task"
}

cmd_review() {
  local project task
  if [ "${1:-}" = "--here" ]; then
    project="$WORKSPACE_DEFAULT"; shift
  elif [ -d "${1:-}" ]; then
    project="$1"; shift
  else
    project="$WORKSPACE_DEFAULT"
  fi
  task="$*"
  [ -z "$task" ] && { color red "Usage: ofs review [project_path] \"review question\""; echo; exit 1; }
  validate_project "$project"
  log "review" "start" "$task"
  "$ROOT/scripts/ask-claude-review.sh" "$project" "$task"
}

cmd_strategy() {
  local project task
  if [ "${1:-}" = "--here" ]; then
    project="$WORKSPACE_DEFAULT"; shift
  elif [ -d "${1:-}" ]; then
    project="$1"; shift
  else
    project="$WORKSPACE_DEFAULT"
  fi
  task="$*"
  [ -z "$task" ] && { color red "Usage: ofs strategy [project_path] \"strategy question\""; echo; exit 1; }
  validate_project "$project"
  log "strategy" "start" "$task"
  "$ROOT/scripts/ask-claude-strategy.sh" "$project" "$task"
}

cmd_mac() {
  set +o pipefail  # head -N + sort can close pipes early in some shells
  IFS='|' read -r load avg5 swap_used swap_total swap_pct mem_pressure < <(mac_load) || true
  echo "Mac load:        ${load:-?} (1min) | ${avg5:-?} (5min)"
  echo "Mac swap:        ${swap_pct:-?}% (${swap_used:-?} / ${swap_total:-?} MB)"
  echo "Memory pressure: ${mem_pressure:-?} (60+ OK, 30-60 WARN, <30 CRITICAL)"
  echo
  echo "Top 10 RAM consumers:"
  ps auxw 2>/dev/null | head -1 || true
  ps auxw 2>/dev/null | sort -k4 -rn 2>/dev/null | sed -n '2,11p' | awk '{cmd=$11; for(i=12;i<=NF;i++) cmd=cmd" "$i; printf "  %5.1f%% MEM  %5.1f%% CPU  %s\n", $4, $3, substr(cmd,1,80)}'
  set -o pipefail
  log "mac" "ok" ""
}

cmd_vps() {
  local v
  v=$(vps_status)
  case "$v" in
    wg|public)
      local target=$VPS_WG
      [ "$v" = "public" ] && target=$VPS_PUBLIC
      ssh -o ConnectTimeout=8 "$target" "echo '=== UPTIME ==='; uptime; echo '=== RAM ==='; free -h | head -3; echo '=== DISK ==='; df -h / | tail -1; echo '=== SERVICES ==='; systemctl list-units --type=service --state=running 2>/dev/null | grep -iE 'hermes|conductor|paseo|caddy|postfix|wg-quick' | head -10; echo '=== CONDUCTOR QUEUE ==='; ls /opt/conductor/queue/inbox/*.json 2>/dev/null | wc -l | xargs -I {} echo 'inbox: {} pending'; ls /opt/conductor/queue/active/*.json 2>/dev/null | wc -l | xargs -I {} echo 'active: {} running'"
      log "vps" "ok" "via $v"
      ;;
    down)
      color red "VPS Flash DOWN — recovery doc: $ROOT/RECOVERY-VPS-FLASH.md"; echo
      log "vps" "down" ""
      exit 2
      ;;
  esac
}

cmd_update() {
  echo "Running update-core.sh (gcloud + VS Code extensions + brew + doctor)..."
  log "update" "start" ""
  "$ROOT/scripts/update-core.sh"
  log "update" "ok" ""
}

cmd_doctor() {
  log "doctor" "start" ""
  "$ROOT/scripts/doctor.sh"
}

cmd_handoffs() {
  local n="${1:-10}"
  echo "Recent $n handoffs (audit trail):"
  ls -1t "$ROOT/handoffs/"*.md 2>/dev/null | head -"$n" | while read -r f; do
    local fname mtime
    fname="$(basename "$f")"
    mtime="$(stat -f '%Sm' -t '%Y-%m-%d %H:%M' "$f" 2>/dev/null)"
    echo "  $mtime  $fname"
  done
  echo
  echo "Tail one: ofs handoff <filename>"
}

cmd_handoff() {
  local f="${1:-}"
  [ -z "$f" ] && { color red "Usage: ofs handoff <filename>"; echo; exit 1; }
  local full="$ROOT/handoffs/$f"
  [ -f "$full" ] || { color red "Not found: $full"; echo; exit 2; }
  cat "$full"
}

cmd_phone() {
  cat <<'EOF'
Phone control plane (mobile dispatcher):

Setup status:
  - Hermes Agent installed on Flash (/usr/local/bin/hermes)
  - Telegram bot: NOT YET CONFIGURED (Wave 2 — vyžaduje VPS up)

Once configured (Wave 2):
  - Open Telegram → @oneflow_dispatch_bot (TBD)
  - Send: /dispatch <free-form task>
  - Bot routes to Conductor inbox on Flash
  - Result reply with task ID + link to handoff
  - Status pull: /status → ekosystem health JSON

Until then:
  - Use VS Code Remote SSH to Flash → claude session there
  - ssh root@10.77.0.1 → submit tasks manually to Conductor
EOF
  log "phone" "info" ""
}

cmd_logs() {
  local n="${1:-30}"
  if [ ! -f "$LOG_FILE" ]; then
    echo "No ofs log yet: $LOG_FILE"
    return
  fi
  tail -"$n" "$LOG_FILE" | while read -r line; do
    echo "$line" | python3 -c 'import json,sys; d=json.loads(sys.stdin.read()); print(f"{d[\"ts\"]}  {d[\"action\"]:10s}  {d[\"status\"]:8s}  {d[\"detail\"][:80]}")'  2>/dev/null || echo "$line"
  done
}

cmd_help() {
  cat <<'EOF'
ofs — OneFlow System dispatcher

USAGE
  ofs <command> [args]

COMMANDS

  Status & monitoring
    status              full ecosystem status (VPS + Mac + sync + CLIs)
    mac                 Mac RAM/swap/CPU + top consumers
    vps                 VPS Flash status (uptime, services, queue)
    doctor              full diagnostic (CLI versions, configs, updates)

  Routing (delegates to ai-control-plane)
    route [path] "task"   intelligent router (codex / claude / local)
    delegate [path] "task" Codex implementation (lean default, full for cloud/MCP)
    review [path] "task"  Claude review/risk gate
    strategy [path] "task" Claude strategy/architecture (no edit)

  Maintenance
    update              run update-core (gcloud + VS Code ext + brew + doctor)
    handoffs [N]        list last N handoffs (default 10)
    handoff <file>      tail specific handoff
    logs [N]            tail ofs audit log (default 30)

  Mobile
    phone               phone control plane info / setup status

  Help
    help, -h, --help    this message

ENV
  OFS_CODEX_MODE        auto (default) | lean | full — for `delegate`

PATHS
  Default project       ~/Desktop/Codex
  Use "--here" or absolute path to override

SHORTCUTS
  ofs status            (most common)
  ofs route --here "fix tests in this repo"
  ofs delegate ~/Documents/website-cloner "refactor cron handler"

EOF
}

# ─── DISPATCH ──────────────────────────────────────────────────────────
case "${1:-help}" in
  status|s)    shift; cmd_status "$@" ;;
  route|r)     shift; cmd_route "$@" ;;
  delegate|d)  shift; cmd_delegate "$@" ;;
  review|rv)   shift; cmd_review "$@" ;;
  strategy|st) shift; cmd_strategy "$@" ;;
  mac|m)       shift; cmd_mac "$@" ;;
  vps|v)       shift; cmd_vps "$@" ;;
  update|u)    shift; cmd_update "$@" ;;
  doctor|dr)   shift; cmd_doctor "$@" ;;
  handoffs|h)  shift; cmd_handoffs "$@" ;;
  handoff)     shift; cmd_handoff "$@" ;;
  logs|l)      shift; cmd_logs "$@" ;;
  phone|p)     shift; cmd_phone "$@" ;;
  help|-h|--help) cmd_help ;;
  *)           color red "Unknown command: $1"; echo; cmd_help; exit 1 ;;
esac
