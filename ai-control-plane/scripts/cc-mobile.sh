#!/usr/bin/env bash
# cc-mobile — spustí Claude Code Remote Control session pro mobilní ovládání
# Native Anthropic feature (Claude Code v2.1.51+). Výsledek: scan QR z Claude
# iOS/Android app a ovládáš stejnou session jako z VS Studio na PC.
#
# Použití:
#   cc-mobile                    # default: Codex root, name = "Filip Codex"
#   cc-mobile --here             # aktuální $PWD
#   cc-mobile /path/to/project   # explicit project root
#   cc-mobile --here "Custom"    # custom session title
#   cc-mobile --worktree         # každá vzdálená session = vlastní git worktree
#   cc-mobile --interactive      # interaktivní režim (terminál + remote naráz)
#
# Po spuštění:
#   1. Stiskni MEZERNÍK → zobrazí QR kód
#   2. Otevři Claude app na iPhone (App Store: "Claude by Anthropic")
#   3. Login stejným Anthropic Max účtem jako Claude Code
#   4. Scan QR → session aktivní z mobilu
#
# Push notifikace: spusť `/config` v session a zapni "Push when Claude decides"
# (vyžaduje Claude Code v2.1.110+; máš 2.1.126 ✓)
#
# Bezpečnost: outbound HTTPS only, žádné inbound porty. Filesystem + MCP servery
# zůstávají na Macu. Anthropic API funguje jako relay (TLS, short-lived creds).
#
# Author: Dopita, 2026-05-03

set -euo pipefail

# ─── DEFAULTS ──────────────────────────────────────────────────────────
DEFAULT_PROJECT="/Users/filipdopita/Desktop/Codex"
DEFAULT_NAME_PREFIX="Filip"
LOG_FILE="$HOME/.claude/logs/cc-mobile.log"
mkdir -p "$(dirname "$LOG_FILE")"

# ─── ARG PARSE ─────────────────────────────────────────────────────────
project=""
session_name=""
mode="server"        # server | interactive
spawn_mode=""        # same-dir (default) | worktree | session
extra_args=()

while [ $# -gt 0 ]; do
  case "$1" in
    --here)         project="$PWD"; shift ;;
    --interactive)  mode="interactive"; shift ;;
    --worktree)     spawn_mode="worktree"; shift ;;
    --session)      spawn_mode="session"; shift ;;
    -h|--help)
      sed -n '2,30p' "$0" | sed 's/^# \?//'
      exit 0 ;;
    --*)            extra_args+=("$1"); shift ;;
    *)
      if [ -z "$project" ] && [ -d "$1" ]; then
        project="$1"
      elif [ -z "$session_name" ]; then
        session_name="$1"
      else
        extra_args+=("$1")
      fi
      shift ;;
  esac
done

[ -z "$project" ] && project="$DEFAULT_PROJECT"
project="$(cd "$project" 2>/dev/null && pwd)" || {
  echo "ERR: project path neexistuje: $project" >&2
  exit 1
}

if [ -z "$session_name" ]; then
  base="$(basename "$project")"
  session_name="$DEFAULT_NAME_PREFIX $base"
fi

# ─── PRE-FLIGHT ────────────────────────────────────────────────────────
if ! command -v claude >/dev/null 2>&1; then
  echo "ERR: claude CLI nenalezen v PATH" >&2
  exit 1
fi

ver="$(claude --version 2>&1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)"
need="2.1.51"
if [ "$(printf '%s\n%s\n' "$need" "$ver" | sort -V | head -1)" != "$need" ]; then
  echo "ERR: Claude Code $ver < $need (Remote Control vyžaduje 2.1.51+)" >&2
  exit 1
fi

# ─── DISPLAY HEADER ────────────────────────────────────────────────────
cat <<EOF
╭──────────────────────────────────────────────────────────────────╮
│  Claude Code Remote Control — Mobile Session                     │
├──────────────────────────────────────────────────────────────────┤
│  Project:   $project
│  Session:   $session_name
│  Mode:      $mode${spawn_mode:+ ($spawn_mode)}
│  Version:   $ver
│  Account:   Anthropic Max (sdílený mezi Claude Code + iOS app)   │
╰──────────────────────────────────────────────────────────────────╯

Po spuštění:
  → Stiskni MEZERNÍK pro zobrazení QR kódu
  → V Claude iOS app: scan QR (App Store: "Claude by Anthropic")
  → Push notifikace: v session spusť "/config" a zapni
                      "Push when Claude decides"

Pro úplný přehled mobile-control: cat /Users/filipdopita/Desktop/Codex/ai-control-plane/MOBILE-DISPATCH.md
EOF

ts="$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
printf '{"ts":"%s","action":"cc-mobile-launch","project":"%s","name":"%s","mode":"%s"}\n' \
  "$ts" "$project" "$session_name" "$mode" >> "$LOG_FILE"

# ─── DISPATCH ──────────────────────────────────────────────────────────
cd "$project"

if [ "$mode" = "interactive" ]; then
  exec claude --remote-control "$session_name" "${extra_args[@]}"
else
  cmd=(claude remote-control --name "$session_name")
  [ -n "$spawn_mode" ] && cmd+=(--spawn "$spawn_mode")
  cmd+=("${extra_args[@]}")
  exec "${cmd[@]}"
fi
