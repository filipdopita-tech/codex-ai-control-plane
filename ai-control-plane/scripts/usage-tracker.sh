#!/usr/bin/env bash
# usage-tracker.sh — Cross-provider usage snapshot (Anthropic + OpenAI + ntfy summary)
#
# Reads from local Claude + Codex session logs (no API call cost).
# Filip rules: 0 cost (no billing API call), security (no secrets in output).
#
# Run: daily 09:00 via launchd
# Output: ~/.claude/logs/usage-daily.jsonl + macOS notify summary
#
# Author: Dopita, 2026-05-02

set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LOG="$HOME/.claude/logs/usage-daily.jsonl"
TODAY=$(date -u '+%Y-%m-%d')
SINCE_TS=$(date -v-24H -u '+%Y-%m-%dT%H:%M:%SZ' 2>/dev/null || date -d '24 hours ago' -u '+%Y-%m-%dT%H:%M:%SZ' 2>/dev/null)
SINCE_EPOCH=$(date -v-24H '+%s' 2>/dev/null || date -d '24 hours ago' '+%s' 2>/dev/null || echo 0)

mkdir -p "$(dirname "$LOG")"

ts() { date -u '+%Y-%m-%dT%H:%M:%SZ'; }

# ─── Claude Code session estimation ──────────────────
# Claude Code logs tool calls to ~/.claude/logs/tool-usage.jsonl (when velocity-monitor hook active)
# Plus session transcripts in ~/.claude/projects/*/sessions/*.json (if archived)
claude_tool_calls=0
claude_token_estimate=0
if [ -f "$HOME/.claude/logs/tool-usage.jsonl" ]; then
  claude_tool_calls=$(awk -v since="$SINCE_TS" 'BEGIN{c=0} /"ts":/ {if (match($0, /"ts":"[^"]+"/)) {tsval=substr($0, RSTART+6, RLENGTH-7); if (tsval >= since) c++}} END{print c}' "$HOME/.claude/logs/tool-usage.jsonl" 2>/dev/null || echo 0)
fi
if [ -f "$HOME/.claude/logs/velocity.jsonl" ]; then
  claude_token_estimate=$(awk -v since="$SINCE_TS" 'BEGIN{t=0} /"ts":/ {if (match($0, /"ts":"[^"]+"/)) {tsval=substr($0, RSTART+6, RLENGTH-7); if (tsval >= since) {if (match($0, /"tokens":[0-9]+/)) {tval=substr($0, RSTART+9, RLENGTH-9); t+=tval}}}} END{print t}' "$HOME/.claude/logs/velocity.jsonl" 2>/dev/null || echo 0)
fi

# ─── Codex CLI session estimation ────────────────────
# Codex stores history in ~/.codex/sessions/ (per session JSONL)
codex_sessions=0
codex_token_estimate=0
if [ -d "$HOME/.codex/sessions" ]; then
  codex_sessions=$(find "$HOME/.codex/sessions" -type f -name '*.jsonl' -exec sh -c '
    since="$1"
    shift
    for f do
      mtime=$(stat -f %m "$f" 2>/dev/null || stat -c %Y "$f" 2>/dev/null || echo 0)
      [ "$mtime" -ge "$since" ] && printf ".\n"
    done
  ' sh "$SINCE_EPOCH" {} + 2>/dev/null | wc -l | tr -d ' ')
  # Token estimate: count input/output messages × avg tokens
  while IFS= read -r -d '' f; do
    mtime=$(stat -f %m "$f" 2>/dev/null || stat -c %Y "$f" 2>/dev/null || echo 0)
    [ "$mtime" -lt "$SINCE_EPOCH" ] && continue
    msgs=$(wc -l < "$f" 2>/dev/null || echo 0)
    codex_token_estimate=$((codex_token_estimate + msgs * 500))  # rough estimate
  done < <(find "$HOME/.codex/sessions" -type f -name '*.jsonl' -print0 2>/dev/null)
fi

# ─── ofs handoffs count (audit trail) ────────────────
handoffs_today=0
if [ -d "$ROOT/handoffs" ]; then
  handoffs_today=$(find "$ROOT/handoffs" -type f -name '*.md' -exec sh -c '
    since="$1"
    shift
    for f do
      mtime=$(stat -f %m "$f" 2>/dev/null || stat -c %Y "$f" 2>/dev/null || echo 0)
      [ "$mtime" -ge "$since" ] && printf ".\n"
    done
  ' sh "$SINCE_EPOCH" {} + 2>/dev/null | wc -l | tr -d ' ')
fi

# ─── Conductor task count (if VPS up) ────────────────
conductor_done=0
if ssh -o ConnectTimeout=4 -o BatchMode=yes root@10.77.0.1 "true" 2>/dev/null; then
  conductor_done=$(ssh -o ConnectTimeout=4 root@10.77.0.1 "find /opt/conductor/queue/done -type f -newermt '$SINCE_TS' 2>/dev/null | wc -l" 2>/dev/null | tr -d ' ' || echo 0)
fi

# ─── Snapshot (no secrets, just counts) ──────────────
snapshot=$(printf '{"ts":"%s","date":"%s","claude":{"tool_calls":%s,"token_estimate":%s},"codex":{"sessions":%s,"token_estimate":%s},"handoffs":%s,"conductor_done":%s}' \
  "$(ts)" "$TODAY" "${claude_tool_calls:-0}" "${claude_token_estimate:-0}" "${codex_sessions:-0}" "${codex_token_estimate:-0}" "${handoffs_today:-0}" "${conductor_done:-0}")

echo "$snapshot" >> "$LOG"

# Human summary
if [ -t 1 ]; then
  echo "Usage last 24h ($SINCE_TS → $(ts)):"
  echo "  Claude Code: $claude_tool_calls tool calls, ~$claude_token_estimate tokens"
  echo "  Codex CLI:   $codex_sessions sessions, ~$codex_token_estimate tokens"
  echo "  Handoffs:    $handoffs_today (Mac dispatch)"
  echo "  Conductor:   $conductor_done done (VPS queue)"
  echo
  echo "Cost: $0 raw API (Max sub Anthropic + Plus OpenAI flat rates)"
  echo "Stack monthly: ~\$230 (Anthropic Max \$200 + OpenAI Plus \$20 + Contabo \$9.62)"
fi

# Notify on extreme volume (>20k tool calls/day = unusually high)
if [ "$claude_tool_calls" -gt 20000 ]; then
  osascript -e "display notification \"$claude_tool_calls Claude tool calls in last 24h. Check usage-daily.jsonl.\" with title \"⚠ High usage\"" 2>/dev/null || true
fi

exit 0
