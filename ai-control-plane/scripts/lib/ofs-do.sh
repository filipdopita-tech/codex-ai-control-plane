#!/usr/bin/env bash
# ofs do — smart intent router
# Analyzuje task a routuje na nejlepší path (Codex / Claude review / dispatch / ntfy / capture).
# Anti-halucinace: pattern match → explicit decision string → log.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
LOG_DIR="$HOME/.claude/logs"
LOG_FILE="$LOG_DIR/ofs.jsonl"
mkdir -p "$LOG_DIR"

ts() { date -u '+%Y-%m-%dT%H:%M:%SZ'; }

log_decision() {
  local intent="$1" route="$2" task="$3"
  printf '{"ts":"%s","action":"do","intent":"%s","route":"%s","task":"%s"}\n' \
    "$(ts)" "$intent" "$route" "$(printf '%s' "$task" | head -c 200 | sed 's/"/\\"/g')" \
    >> "$LOG_FILE"
}

usage() {
  cat <<'EOF'
Usage: ofs do "task description"

Smart intent router. Analyzuje task a vybere nejvhodnější cestu:
  - capture    → ofs capture (idea/note/myslenka)
  - notify     → ofs notify (alert/push/poslat info)
  - dispatch   → ofs dispatch (mobile/remote z telefonu)
  - codex      → ofs delegate (implementace/refactor/build)
  - review     → ofs review (audit/check/zkontroluj)
  - brand      → ofs brand (brand check/voice audit)
  - eval       → ofs eval (high-stakes copy/DD/outreach)
  - heal       → ofs heal (services down, restart)
  - status     → ofs status (snapshot)
  - chat       → vrať doporučení použít přímo Claude session

Příklady:
  ofs do "implement webhook handler in /tmp/foo"
  ofs do "zkontroluj outreach email pro Karla"
  ofs do "uložit nápad: weekly newsletter automation"
  ofs do "VPS down — heal"
EOF
  exit "${1:-1}"
}

[ $# -ge 1 ] || usage
[ "${1:-}" = "--help" ] && usage 0

TASK="$*"
TASK_LOWER=$(printf '%s' "$TASK" | tr '[:upper:]' '[:lower:]')

# Intent detection — pattern based, deterministic
detect_intent() {
  local t="$1"
  # capture (highest priority — explicit save intent)
  if printf '%s' "$t" | grep -qE '(uložit nápad|save idea|capture|zapamatuj|poznamenej|note this|nápad:)'; then
    echo "capture"; return
  fi
  # notify
  if printf '%s' "$t" | grep -qE '(notify|notifikuj|push to phone|pošli na telefon|alert)'; then
    echo "notify"; return
  fi
  # heal
  if printf '%s' "$t" | grep -qE '(heal|down|restart|spadlo|nefunguje|services down|není online)'; then
    echo "heal"; return
  fi
  # status
  if printf '%s' "$t" | grep -qE '^(status|stav|jak to vypadá|health|snapshot)$|status check'; then
    echo "status"; return
  fi
  # eval (high-stakes content audit)
  if printf '%s' "$t" | grep -qE '(eval|vyhodnoť|posuď|score this|auto-eval|kvalita)'; then
    echo "eval"; return
  fi
  # brand (banned words / voice audit)
  if printf '%s' "$t" | grep -qE '(brand check|voice audit|banned words|zkontroluj voice|brand-check)'; then
    echo "brand"; return
  fi
  # review (audit / check / verify EXISTING work)
  if printf '%s' "$t" | grep -qE '(zkontroluj|audit|review|prověř|posuď|check this|peer review|second opinion)'; then
    echo "review"; return
  fi
  # codex (implementation keywords)
  if printf '%s' "$t" | grep -qE '(implement|refactor|fix bug|sprav|naimplementuj|napsat funkci|build (a|the) |create (a |the )?(script|file|module)|write (a |the )?(script|test|function))'; then
    echo "codex"; return
  fi
  # dispatch (remote/phone)
  if printf '%s' "$t" | grep -qE '(dispatch|z telefonu|remote run|spustit přes hermes)'; then
    echo "dispatch"; return
  fi
  # default → chat (let Claude session handle)
  echo "chat"
}

INTENT=$(detect_intent "$TASK_LOWER")

# Route mapping
case "$INTENT" in
  capture)
    ROUTE="ofs capture"
    log_decision "$INTENT" "$ROUTE" "$TASK"
    echo "→ Routing: capture (save to vault inbox + memory)"
    exec "$ROOT/scripts/lib/ofs-capture.sh" "$TASK"
    ;;
  notify)
    ROUTE="ofs notify"
    log_decision "$INTENT" "$ROUTE" "$TASK"
    echo "→ Routing: notify (push to phone)"
    exec "$ROOT/scripts/ofs.sh" notify "$TASK"
    ;;
  heal)
    ROUTE="ofs heal"
    log_decision "$INTENT" "$ROUTE" "$TASK"
    echo "→ Routing: heal (restart down services + ntfy)"
    exec "$ROOT/scripts/lib/ofs-heal.sh"
    ;;
  status)
    ROUTE="ofs status"
    log_decision "$INTENT" "$ROUTE" "$TASK"
    exec "$ROOT/scripts/ofs.sh" status
    ;;
  eval)
    ROUTE="ofs eval"
    log_decision "$INTENT" "$ROUTE" "$TASK"
    echo "→ Routing: eval (auto-quality check)"
    exec "$ROOT/scripts/lib/ofs-eval.sh" "$TASK"
    ;;
  brand)
    ROUTE="ofs brand"
    log_decision "$INTENT" "$ROUTE" "$TASK"
    echo "→ Routing: brand (banned words + voice)"
    exec "$ROOT/scripts/lib/ofs-brand.sh" "$TASK"
    ;;
  review)
    ROUTE="ofs review --here"
    log_decision "$INTENT" "$ROUTE" "$TASK"
    echo "→ Routing: review --here (Claude review)"
    exec "$ROOT/scripts/ofs.sh" review --here "$TASK"
    ;;
  codex)
    ROUTE="ofs delegate --here"
    log_decision "$INTENT" "$ROUTE" "$TASK"
    echo "→ Routing: delegate --here (Codex implementace)"
    exec "$ROOT/scripts/ofs.sh" delegate --here "$TASK"
    ;;
  dispatch)
    ROUTE="ofs dispatch"
    log_decision "$INTENT" "$ROUTE" "$TASK"
    echo "→ Routing: dispatch (Hermes webhook gateway)"
    exec "$ROOT/scripts/ofs.sh" dispatch "$TASK"
    ;;
  chat|*)
    ROUTE="claude-session-direct"
    log_decision "$INTENT" "$ROUTE" "$TASK"
    cat <<EOF
→ Intent: chat (žádný explicit routing trigger)

Doporučení: zpracuj přímo v Claude session — task nevyžaduje delegation.

Pokud chceš explicit route:
  ofs delegate --here "$TASK"     # Codex implementace
  ofs review --here "$TASK"       # Claude review
  ofs capture "$TASK"             # save jako nápad
  ofs dispatch "$TASK"            # remote přes Hermes
EOF
    ;;
esac
