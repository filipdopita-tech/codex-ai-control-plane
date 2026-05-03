#!/usr/bin/env bash
# flash-rc-setup — one-time setup pro always-on Claude Code Remote Control na Flash VPS
# Filip spustí jednou na Macu. Skript:
#   1. ssh na Flash, spustí `claude auth login` (Filip projde claude.ai OAuth v browseru)
#   2. Ověří loggedIn: true
#   3. Vytvoří workspace-rc dir + deploy systemd unit
#   4. Enable + start systemd unit (auto-restart on crash, survives ssh logout)
#   5. Ověří že RC session žije a registrovala se k Anthropic API
#
# Po dokončení: v Claude iOS app uvidíš session "Filip Flash" v session list.
# Tap → ovládáš Flash 24/7.
#
# Usage:
#   bash flash-rc-setup.sh             # interactive setup
#   bash flash-rc-setup.sh --reauth    # force re-login (token expirace nebo zlomený)
#   bash flash-rc-setup.sh --dry-run   # ukáž co by se dělo, neproveď
#
# Author: Dopita, 2026-05-03

set -euo pipefail

# ─── CONFIG ───────────────────────────────────────────────────────────
VPS="root@10.77.0.1"
VPS_PUBLIC="root@173.212.220.67"
RC_WORKSPACE="/root/workspace-rc"
SERVICE_NAME="claude-rc"
SERVICE_FILE="/etc/systemd/system/${SERVICE_NAME}.service"
LOCAL_UNIT="$(cd "$(dirname "$0")" && pwd)/lib/claude-rc-flash.service"

REAUTH=0
DRY=0
FROM_MAC=0
MAC_CREDS="/Users/filipdopita/.claude/.credentials.json"
for a in "$@"; do
  case "$a" in
    --reauth)   REAUTH=1 ;;
    --from-mac) FROM_MAC=1; REAUTH=1 ;;
    --dry-run)  DRY=1 ;;
    -h|--help)  sed -n '2,18p' "$0" | sed 's/^# \?//'; exit 0 ;;
  esac
done

# ─── HELPERS ──────────────────────────────────────────────────────────
say()  { printf "\033[1;34m▶\033[0m %s\n" "$*"; }
ok()   { printf "\033[1;32m✓\033[0m %s\n" "$*"; }
warn() { printf "\033[1;33m!\033[0m %s\n" "$*"; }
err()  { printf "\033[1;31m✗\033[0m %s\n" "$*" >&2; }

run_remote() {
  local cmd="$1"
  if [ "$DRY" -eq 1 ]; then
    echo "[DRY] ssh $VPS \"$cmd\""
  else
    ssh -o ConnectTimeout=8 "$VPS" "$cmd"
  fi
}

# ─── PRE-FLIGHT ───────────────────────────────────────────────────────
say "Pre-flight check"

if ! ssh -o ConnectTimeout=5 -o BatchMode=yes "$VPS" "true" 2>/dev/null; then
  err "VPS Flash unreachable přes WG ($VPS). Zkus přes public IP nebo zkontroluj WireGuard."
  exit 1
fi
ok "VPS reachable"

if [ ! -f "$LOCAL_UNIT" ]; then
  err "Systemd unit template nenalezený: $LOCAL_UNIT"
  exit 1
fi
ok "Unit template found: $LOCAL_UNIT"

VPS_VER="$(ssh "$VPS" 'claude --version 2>&1 | grep -oE "[0-9]+\.[0-9]+\.[0-9]+" | head -1')"
NEED="2.1.51"
if [ "$(printf '%s\n%s\n' "$NEED" "$VPS_VER" | sort -V | head -1)" != "$NEED" ]; then
  err "Flash Claude Code $VPS_VER < $NEED. Update needed."
  exit 1
fi
ok "Flash Claude Code: $VPS_VER (≥ $NEED)"

# ─── STEP 1 — AUTH ────────────────────────────────────────────────────
say "Krok 1/4 — Authentication"

AUTH_STATUS="$(run_remote 'claude auth status 2>/dev/null' || echo '{}')"
LOGGED_IN="$(echo "$AUTH_STATUS" | grep -oE '"loggedIn":[[:space:]]*(true|false)' | grep -oE '(true|false)' || echo 'unknown')"

if [ "$LOGGED_IN" = "true" ] && [ "$REAUTH" -eq 0 ]; then
  ok "Already logged in (přidej --reauth nebo --from-mac pokud chceš změnit account)"
elif [ "$FROM_MAC" -eq 1 ]; then
  # Path B: Transfer Mac credentials directly (no browser flow)
  if [ ! -s "$MAC_CREDS" ]; then
    err "Mac credentials nenalezeny: $MAC_CREDS"
    err "Spusť 'claude auth status' v Mac terminálu pro vytvoření, nebo použij --reauth (browser flow)."
    exit 2
  fi
  say "Path B: --from-mac transfer (bez browser flow)"
  ok "Mac creds: $MAC_CREDS"

  # Decode email/orgId for clarity (no token printout)
  ACCT_INFO="$(python3 -c "
import json
d = json.load(open('$MAC_CREDS'))
print(f\"orgId={d.get('organizationUuid','?')}\")
" 2>&1)"
  echo "  Mac account: $ACCT_INFO"

  if [ "$DRY" -eq 0 ]; then
    [ "$LOGGED_IN" = "true" ] && warn "Stop service before swap" && run_remote "systemctl stop claude-rc 2>/dev/null || true"

    scp -q "$MAC_CREDS" "$VPS:/root/.claude/.credentials.json"
    run_remote "chmod 600 /root/.claude/.credentials.json"

    # Sync oauthAccount cache from Mac global config to Flash (so CLI knows email/orgId)
    MAC_OAUTH_JSON="$(python3 -c "
import json
d = json.load(open('/Users/filipdopita/.claude.json'))
print(json.dumps(d.get('oauthAccount', {})))
" 2>/dev/null)"

    if [ -n "$MAC_OAUTH_JSON" ] && [ "$MAC_OAUTH_JSON" != "{}" ]; then
      run_remote "python3 -c \"
import json, os
d = json.load(open('/root/.claude.json'))
d['oauthAccount'] = json.loads(r'''$MAC_OAUTH_JSON''')
json.dump(d, open('/root/.claude.json', 'w'), indent=2)
os.chmod('/root/.claude.json', 0o600)
\""
      ok "oauthAccount cache synced from Mac"
    else
      run_remote "python3 -c \"
import json, os
d = json.load(open('/root/.claude.json'))
d.pop('oauthAccount', None)
json.dump(d, open('/root/.claude.json', 'w'), indent=2)
os.chmod('/root/.claude.json', 0o600)
\""
      warn "Mac oauthAccount empty — popped Flash cache (CLI will refetch)"
    fi

    # Verify
    AUTH_STATUS="$(run_remote 'claude auth status 2>/dev/null')"
    LOGGED_IN="$(echo "$AUTH_STATUS" | grep -oE '\"loggedIn\":[[:space:]]*(true|false)' | grep -oE '(true|false)')"
    EMAIL="$(echo "$AUTH_STATUS" | grep -oE '\"email\":[[:space:]]*\"[^\"]+\"' | sed 's/.*\"\(.*\)\"/\1/')"
    if [ "$LOGGED_IN" != "true" ]; then
      err "Auth failed po transferu. AUTH_STATUS: $AUTH_STATUS"
      exit 3
    fi
    ok "Logged in jako: $EMAIL"
  fi
else
  if [ "$LOGGED_IN" = "true" ] && [ "$REAUTH" -eq 1 ]; then
    warn "Force logout (--reauth)"
    [ "$DRY" -eq 0 ] && run_remote "claude auth logout 2>&1 || true"
  fi

  cat <<'EOF'

  ╭─────────────────────────────────────────────────────────────────╮
  │  BROWSER LOGIN — Anthropic claude.ai OAuth                      │
  │                                                                 │
  │  Za chvíli se otevře interaktivní `claude auth login` na Flash. │
  │  Vytiskne URL — zkopíruj ji do browseru NA MACU NEBO PHONE.     │
  │  Login svým Anthropic Max účtem. Po autorizaci OAuth callback   │
  │  vrátí kód (nebo ho zobrazí).                                   │
  │                                                                 │
  │  Pokud CLI request "Paste code here:", zkopíruj kód a vlož.     │
  │  Pokud CLI request "Press Enter when authorized", autorizuj v   │
  │  browseru a stiskni Enter v terminálu.                          │
  ╰─────────────────────────────────────────────────────────────────╯

EOF
  read -r -p "Press Enter to start login..." _

  if [ "$DRY" -eq 1 ]; then
    echo "[DRY] ssh -t $VPS 'claude auth login --claudeai'"
  else
    ssh -t "$VPS" 'claude auth login --claudeai'
  fi

  # Re-check
  AUTH_STATUS="$(run_remote 'claude auth status 2>/dev/null' || echo '{}')"
  LOGGED_IN="$(echo "$AUTH_STATUS" | grep -oE '"loggedIn":[[:space:]]*(true|false)' | grep -oE '(true|false)' || echo 'unknown')"

  if [ "$LOGGED_IN" != "true" ] && [ "$DRY" -eq 0 ]; then
    err "Login se nedokončil (loggedIn=$LOGGED_IN). Restart skriptu nebo zkus ručně:"
    err "  ssh -t $VPS 'claude auth login --claudeai'"
    exit 2
  fi
  ok "Login úspěšný"
fi

# ─── STEP 2 — WORKSPACE ───────────────────────────────────────────────
say "Krok 2/4 — Workspace setup"

run_remote "
  mkdir -p $RC_WORKSPACE
  cd $RC_WORKSPACE
  if [ ! -d .git ]; then
    git init -q 2>/dev/null
    git config user.email 'rc@flash.oneflow.cz' 2>/dev/null
    git config user.name 'Filip Flash RC' 2>/dev/null
    echo '# Workspace pro Flash RC sessions (worktree spawn)' > README.md
    git add README.md 2>/dev/null
    git commit -q -m 'init' 2>/dev/null
  fi
  ls -la $RC_WORKSPACE | head -3
"
ok "Workspace ready: $RC_WORKSPACE"

# ─── STEP 3 — SYSTEMD UNIT ────────────────────────────────────────────
say "Krok 3/4 — Systemd unit deploy"

if [ "$DRY" -eq 1 ]; then
  echo "[DRY] scp $LOCAL_UNIT $VPS:$SERVICE_FILE"
  echo "[DRY] ssh $VPS systemctl daemon-reload"
  echo "[DRY] ssh $VPS systemctl enable $SERVICE_NAME"
  echo "[DRY] ssh $VPS systemctl restart $SERVICE_NAME"
else
  scp -q "$LOCAL_UNIT" "$VPS:$SERVICE_FILE"
  run_remote "systemctl daemon-reload"
  run_remote "systemctl enable $SERVICE_NAME 2>&1 | grep -v 'Created\|already' || true"
  run_remote "systemctl restart $SERVICE_NAME"
  sleep 3
fi
ok "Service deployed: $SERVICE_FILE"

# ─── STEP 4 — VERIFY ──────────────────────────────────────────────────
say "Krok 4/4 — Verifikace"

if [ "$DRY" -eq 0 ]; then
  STATE="$(run_remote "systemctl is-active $SERVICE_NAME" 2>&1)"
  if [ "$STATE" = "active" ]; then
    ok "Service active"
  else
    err "Service not active: $STATE"
    run_remote "systemctl status $SERVICE_NAME --no-pager 2>&1 | head -20"
    exit 3
  fi

  sleep 2
  LOG_TAIL="$(run_remote "tail -20 /var/log/claude-rc.log 2>/dev/null" || echo '')"
  if echo "$LOG_TAIL" | grep -qE 'Session URL|registered|listening|Remote Control'; then
    ok "RC session registered with Anthropic API"
  else
    warn "RC log doesn't show registration yet (může trvat 5-10s):"
    echo "$LOG_TAIL" | tail -5 | sed 's/^/    /'
  fi
fi

# ─── FINAL ────────────────────────────────────────────────────────────
cat <<EOF

╭─────────────────────────────────────────────────────────────────╮
│  HOTOVO — Flash RC běží 24/7                                    │
├─────────────────────────────────────────────────────────────────┤
│  Service:    $SERVICE_FILE
│  Workspace:  $RC_WORKSPACE
│  Logs:       /var/log/claude-rc.log
│                                                                 │
│  V Claude iOS app:                                              │
│    Otevři session list → najdi "Filip Flash" (computer ikona,   │
│    zelená tečka = online) → tap → píšeš z phone na Flash 24/7  │
│                                                                 │
│  Kontrola na Macu:                                              │
│    ofs mobile-flash status                                      │
│    ofs mobile-flash logs                                        │
│    ofs mobile-flash restart                                     │
│    ofs mobile-flash reauth   (po expiraci tokenu)               │
╰─────────────────────────────────────────────────────────────────╯

EOF
