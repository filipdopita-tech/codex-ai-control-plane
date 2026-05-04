#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: control-plane-optimize.sh [--fast]

Runs a safe, mostly read-only optimization pass for the AI control plane.

Checks:
  - core update signals via update-core.sh --check-only
  - Mac load/swap pressure
  - MCP process fan-out
  - handoff rotation dry-run
  - git state summary

Flags:
  --fast   skip slower update signal checks; run local pressure/audit only
  --help   show this help

This script does not kill processes, delete files, edit configs, or expose
secrets. It is intended as the daily "what should I fix next?" command.
EOF
}

FAST=0

while [ $# -gt 0 ]; do
  case "${1:-}" in
    --fast)
      FAST=1
      shift
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      echo "Unknown arg: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

section() {
  echo
  echo "== $1 =="
}

warn_count=0
action_count=0

note_warn() {
  warn_count=$((warn_count + 1))
  printf 'WARN  %s\n' "$1"
}

note_action() {
  action_count=$((action_count + 1))
  printf 'NEXT  %s\n' "$1"
}

echo "AI control-plane optimizer"
echo "=========================="
echo "Root: $ROOT"
echo "Mode: $([ "$FAST" -eq 1 ] && echo fast || echo full-check)"

section "Git State"
if [ -d "$ROOT/.git" ]; then
  git -C "$ROOT" status --short --branch | sed -n '1,40p'
  changed="$(git -C "$ROOT" status --short | wc -l | tr -d ' ')"
  if [ "$changed" -gt 20 ] 2>/dev/null; then
    note_warn "$changed changed/untracked paths; keep edits scoped before broad maintenance"
  fi
else
  note_warn "workspace is not a git repo"
fi

if [ "$FAST" -eq 0 ]; then
  section "Core Update Signals"
  "$ROOT/ai-control-plane/scripts/update-core.sh" --check-only || note_warn "update-core check returned non-zero"
else
  section "Core Update Signals"
  echo "SKIP --fast"
fi

section "Mac Pressure"
"$ROOT/ai-control-plane/scripts/mac-load-triage.sh" || note_warn "mac-load-triage failed"
if [ -f "$HOME/.claude/logs/resource-monitor.jsonl" ] && command -v jq >/dev/null 2>&1; then
  latest_resource="$(tail -1 "$HOME/.claude/logs/resource-monitor.jsonl")"
  swap_pct="$(printf '%s' "$latest_resource" | jq -r '.mac.swap_pct // 0' 2>/dev/null || echo 0)"
  stressed="$(printf '%s' "$latest_resource" | jq -r '.mac.stressed // 0' 2>/dev/null || echo 0)"
  route_hint="$(printf '%s' "$latest_resource" | jq -r '.route_hint // "unknown"' 2>/dev/null || echo unknown)"
  if [ "$swap_pct" -ge 80 ] 2>/dev/null || [ "$stressed" = "1" ]; then
    note_warn "Mac pressure high: swap=${swap_pct}% stressed=${stressed} route_hint=${route_hint}"
    note_action "Prefer VPS/offload for long Codex/Claude/browser tasks until swap drops below 80%"
  fi
fi

section "MCP Fan-out"
"$ROOT/ai-control-plane/scripts/mcp-process-audit.sh" || note_warn "mcp-process-audit failed"
mcp_total="$(ps -axo command 2>/dev/null \
  | (egrep 'obsidian-mcp|code-review-graph serve|context7-mcp|stitch-mcp|mcp-server-filesystem|scrapling mcp|memory-search-mcp' || true) \
  | (egrep -v 'egrep|mcp-process-audit|control-plane-optimize' || true) \
  | wc -l \
  | tr -d ' ')"
if [ "$mcp_total" -gt 20 ] 2>/dev/null; then
  note_warn "$mcp_total MCP-like processes running"
  note_action "Close stale Claude/VS Code sessions first; then rerun mcp-process-audit"
fi

section "Handoff Rotation"
"$ROOT/ai-control-plane/scripts/cleanup-handoffs.sh" --dry-run || note_warn "handoff cleanup dry-run failed"

section "Summary"
if [ "$warn_count" -eq 0 ]; then
  echo "OK    no optimizer warnings"
else
  echo "WARN  $warn_count optimizer warning(s)"
fi

if [ "$action_count" -eq 0 ]; then
  echo "NEXT  none"
else
  echo "NEXT  $action_count recommended action(s) listed above"
fi
