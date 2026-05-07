#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
CLAUDE_DIR="${CLAUDE_DIR:-$HOME/.claude}"
CODEX_DIR="${CODEX_DIR:-$HOME/.codex}"
SETTINGS="$CLAUDE_DIR/settings.json"

status() {
  printf "%-6s %-34s %s\n" "$1" "$2" "${3:-}"
}

have() {
  command -v "$1" >/dev/null 2>&1
}

size_mb() {
  local path="$1"
  if [ -e "$path" ]; then
    du -sk "$path" 2>/dev/null | awk '{printf "%.0f", $1 / 1024}'
  else
    echo 0
  fi
}

json_get() {
  local filter="$1"
  jq -r "$filter" "$SETTINGS" 2>/dev/null || true
}

is_high_quality_profile() {
  [ -f "$SETTINGS" ] || return 1
  have jq || return 1

  local model effort thinking
  model="$(jq -r '.model // ""' "$SETTINGS" 2>/dev/null || true)"
  effort="$(jq -r '.env.CLAUDE_CODE_EFFORT_LEVEL // ""' "$SETTINGS" 2>/dev/null || true)"
  thinking="$(jq -r '.env.MAX_THINKING_TOKENS // "0"' "$SETTINGS" 2>/dev/null || true)"

  [ "$model" = "claude-opus-4-7" ] && [ "$effort" = "xhigh" ] && [ "$thinking" = "32000" ]
}

warns=0
fails=0

warn() {
  warns=$((warns + 1))
  status "WARN" "$1" "$2"
}

fail() {
  fails=$((fails + 1))
  status "FAIL" "$1" "$2"
}

ok() {
  status "OK" "$1" "$2"
}

echo "AI ecosystem audit"
echo "=================="
echo

echo "Workspace"
status "INFO" "root" "$ROOT"
if [ -d "$ROOT/.git" ]; then
  git_summary="$(git -C "$ROOT" status --short | wc -l | tr -d ' ')"
  if [ "$git_summary" -gt 40 ]; then
    warn "git working tree" "$git_summary changed/untracked paths"
  else
    ok "git working tree" "$git_summary changed/untracked paths"
  fi
else
  fail "git working tree" "not a git repo"
fi

if [ -d "$ROOT/.claude" ]; then
  claude_local_files="$(find "$ROOT/.claude" -type f ! -name 'scheduled_tasks.lock' 2>/dev/null | wc -l | tr -d ' ')"
  if [ "$claude_local_files" -gt 0 ]; then
    warn "workspace .claude" "$claude_local_files local state files; keep ignored"
  else
    ok "workspace .claude" "empty or lock-only"
  fi
fi
echo

echo "Core commands"
for cmd in codex claude gcloud git rg jq node npm pnpm bun python3 brew; do
  if have "$cmd"; then
    ok "$cmd" "$(command -v "$cmd")"
  else
    fail "$cmd" "not found"
  fi
done
echo

echo "Config sizes"
high_quality_profile=0
if is_high_quality_profile; then
  high_quality_profile=1
fi

claude_mb="$(size_mb "$CLAUDE_DIR")"
claude_projects_mb="$(size_mb "$CLAUDE_DIR/projects")"
claude_codex_project_mb="$(size_mb "$CLAUDE_DIR/projects/-Users-filipdopita-Desktop-Codex")"
claude_skills_mb="$(size_mb "$CLAUDE_DIR/skills")"
claude_plugins_mb="$(size_mb "$CLAUDE_DIR/plugins")"
codex_mb="$(size_mb "$CODEX_DIR")"

if [ "$claude_mb" -gt 4096 ]; then
  fail "global ~/.claude size" "${claude_mb}MB"
elif [ "$claude_mb" -gt 2048 ]; then
  status "INFO" "global ~/.claude size" "${claude_mb}MB (large but below hard ceiling)"
else
  ok "global ~/.claude size" "${claude_mb}MB"
fi

if [ "$claude_projects_mb" -gt 1024 ]; then
  warn "Claude project transcripts" "${claude_projects_mb}MB"
else
  ok "Claude project transcripts" "${claude_projects_mb}MB"
fi

if [ "$claude_codex_project_mb" -gt 150 ]; then
  old_codex_transcripts=0
  if [ -d "$CLAUDE_DIR/projects/-Users-filipdopita-Desktop-Codex" ]; then
    old_codex_transcripts="$(find "$CLAUDE_DIR/projects/-Users-filipdopita-Desktop-Codex" -type f -name '*.jsonl' -mtime +7 2>/dev/null | wc -l | tr -d ' ')"
  fi
  if [ "$old_codex_transcripts" -gt 0 ] 2>/dev/null; then
    warn "Codex workspace Claude history" "${claude_codex_project_mb}MB; $old_codex_transcripts archive-eligible transcript(s)"
  else
    ok "Codex workspace Claude history" "${claude_codex_project_mb}MB active/recent; no archive-eligible transcripts"
  fi
else
  ok "Codex workspace Claude history" "${claude_codex_project_mb}MB"
fi

status "INFO" "Claude skills/plugins" "skills=${claude_skills_mb}MB plugins=${claude_plugins_mb}MB"
status "INFO" "Codex config/cache" "${codex_mb}MB"
echo

echo "Claude Code profile"
if [ ! -f "$SETTINGS" ]; then
  fail "settings.json" "missing at $SETTINGS"
elif ! jq empty "$SETTINGS" >/dev/null 2>&1; then
  fail "settings.json" "invalid JSON"
else
  ok "settings.json" "$SETTINGS"

  model="$(json_get '.model // ""')"
  effort="$(json_get '.env.CLAUDE_CODE_EFFORT_LEVEL // ""')"
  thinking="$(json_get '.env.MAX_THINKING_TOKENS // "0"')"
  compact_pct="$(json_get '.env.CLAUDE_AUTOCOMPACT_PCT_OVERRIDE // ""')"
  away_summary="$(json_get '.env.CLAUDE_CODE_ENABLE_AWAY_SUMMARY // ""')"
  hook_count="$(json_get '(.hooks // {}) | keys | length')"
  risky_hooks="$(json_get '(.hooks // {}) | keys | map(select(. == "UserPromptSubmit" or . == "SessionStart" or . == "Stop" or . == "PostToolUse" or . == "PreCompact")) | join(",")')"
  mcp_count="$(json_get '(.mcpServers // {}) | keys | length')"
  plugin_count="$(json_get '(.enabledPlugins // {}) | keys | length')"
  default_mode="$(json_get '.permissions.defaultMode // ""')"
  allow_count="$(json_get '(.permissions.allow // []) | length')"

  case "$model" in
    sonnet|opus|claude-opus-4-7) ok "Claude model" "$model" ;;
    *) warn "Claude model" "${model:-unset}" ;;
  esac

  if [ "$effort" = "max" ]; then
    warn "Claude effort" "$effort"
  else
    ok "Claude effort" "${effort:-unset}"
  fi

  if [ "$high_quality_profile" = "1" ]; then
    ok "thinking budget" "$thinking (intentional high-quality profile)"
  elif [ "${thinking:-0}" -gt 16000 ] 2>/dev/null; then
    warn "thinking budget" "$thinking"
  else
    ok "thinking budget" "$thinking"
  fi

  if [ "$compact_pct" = "60" ] || [ "$compact_pct" = "65" ] || [ "$compact_pct" = "70" ]; then
    ok "auto-compact threshold" "$compact_pct"
  else
    warn "auto-compact threshold" "${compact_pct:-unset}"
  fi

  if [ "$away_summary" = "0" ]; then
    ok "away summary" "disabled"
  else
    warn "away summary" "${away_summary:-unset}"
  fi

  if [ "$hook_count" -gt 6 ]; then
    warn "Claude hook groups" "$hook_count"
  elif [ "$hook_count" -gt 2 ] && [ "$high_quality_profile" = "1" ]; then
    ok "Claude hook groups" "$hook_count (accepted max-quality profile)"
  elif [ "$hook_count" -gt 2 ]; then
    warn "Claude hook groups" "$hook_count"
  else
    ok "Claude hook groups" "$hook_count"
  fi

  if [ -n "$risky_hooks" ] && [ "$high_quality_profile" = "1" ]; then
    ok "context-expanding hooks" "$risky_hooks (accepted max-quality profile)"
  elif [ -n "$risky_hooks" ]; then
    warn "context-expanding hooks" "$risky_hooks"
  else
    ok "context-expanding hooks" "none"
  fi

  if [ "$mcp_count" -gt 12 ] && [ "$high_quality_profile" = "1" ]; then
    ok "Claude MCP servers" "$mcp_count configured (accepted max-quality profile)"
  elif [ "$mcp_count" -gt 12 ]; then
    warn "Claude MCP servers" "$mcp_count configured"
  else
    ok "Claude MCP servers" "$mcp_count configured"
  fi

  status "INFO" "Claude plugins" "$plugin_count enabled"

  if [ "$default_mode" = "bypassPermissions" ] && [ "$allow_count" -gt 20 ] && [ "$high_quality_profile" = "1" ]; then
    ok "Claude permissions" "bypassPermissions with $allow_count allow rules (accepted max-quality profile)"
  elif [ "$default_mode" = "bypassPermissions" ] && [ "$allow_count" -gt 20 ]; then
    warn "Claude permissions" "bypassPermissions with $allow_count allow rules"
  else
    ok "Claude permissions" "${default_mode:-unset} with $allow_count allow rules"
  fi
fi
echo

echo "Recent large Claude transcripts"
if [ -d "$CLAUDE_DIR/projects" ]; then
  find "$CLAUDE_DIR/projects" -type f -name '*.jsonl' -size +5M -mtime -7 -exec ls -lh {} + 2>/dev/null \
    | sort -k5 -hr \
    | awk '{print "INFO   transcript                         " $5 " " $9}' \
    | sed -n '1,10p'
else
  status "INFO" "transcripts" "none"
fi
echo

echo "Operational monitors"
latest_security="$(ls -t "$CLAUDE_DIR"/logs/security-audit-*.md 2>/dev/null | sed -n '1p' || true)"
if [ -n "$latest_security" ]; then
  critical="$(grep -E '^- \*\*Critical findings:\*\*' "$latest_security" | sed -E 's/.*\*\* ([0-9]+).*/\1/' | sed -n '1p')"
  total_findings="$(grep -E '^- \*\*Total findings:\*\*' "$latest_security" | sed -E 's/.*\*\* ([0-9]+).*/\1/' | sed -n '1p')"
  critical="${critical:-0}"
  total_findings="${total_findings:-0}"
  if [ "$critical" -gt 0 ] 2>/dev/null; then
    fail "latest security audit" "$critical critical finding(s) in $latest_security"
  elif [ "$total_findings" -gt 0 ] 2>/dev/null; then
    warn "latest security audit" "$total_findings finding(s) in $latest_security"
  else
    ok "latest security audit" "0 findings"
  fi
else
  warn "latest security audit" "no report found"
fi

resource_log="$CLAUDE_DIR/logs/resource-monitor.jsonl"
if [ -f "$resource_log" ] && command -v jq >/dev/null 2>&1; then
  latest_resource="$(tail -1 "$resource_log")"
  swap_pct="$(printf "%s" "$latest_resource" | jq -r '.mac.swap_pct // 0' 2>/dev/null || echo 0)"
  mac_stressed="$(printf "%s" "$latest_resource" | jq -r '.mac.stressed // 0' 2>/dev/null || echo 0)"
  route_hint="$(printf "%s" "$latest_resource" | jq -r '.route_hint // "unknown"' 2>/dev/null || echo unknown)"
  vps_state="$(printf "%s" "$latest_resource" | jq -r '.vps.state // "unknown"' 2>/dev/null || echo unknown)"
  if [ "$swap_pct" -ge 90 ] 2>/dev/null; then
    warn "Mac resource state" "swap=${swap_pct}% stressed=${mac_stressed} route_hint=${route_hint} vps=${vps_state}"
  elif [ "$mac_stressed" = "1" ] && [ "$route_hint" = "vps" ] && [ "$vps_state" = "wg" ]; then
    ok "Mac resource state" "managed stress: swap=${swap_pct}% route_hint=${route_hint} vps=${vps_state}"
  elif [ "$mac_stressed" = "1" ]; then
    warn "Mac resource state" "stressed route_hint=${route_hint} vps=${vps_state}"
  else
    ok "Mac resource state" "swap=${swap_pct}% route_hint=${route_hint} vps=${vps_state}"
  fi
else
  warn "resource monitor" "no log found"
fi

if command -v ps >/dev/null 2>&1; then
  mcp_processes="$(ps -axo command 2>/dev/null \
    | (egrep 'obsidian-mcp|code-review-graph serve|context7-mcp|stitch-mcp|mcp-server-filesystem|scrapling mcp|memory-search-mcp' || true) \
    | (egrep -v 'egrep|mcp-process-audit' || true) \
    | wc -l \
    | tr -d ' ')"
  if [ "$mcp_processes" -gt 20 ] 2>/dev/null; then
    cleanup_probe="$(mktemp -t mcp-cleanup-probe.XXXXXX)"
    if "$ROOT/ai-control-plane/scripts/mcp-process-cleanup.sh" --older-than-min 5 > "$cleanup_probe" 2>&1 \
      && grep -q 'No stale duplicate MCP processes selected' "$cleanup_probe"; then
      ok "MCP process count" "$mcp_processes running; no stale cleanup candidates"
    else
      warn "MCP process count" "$mcp_processes running; consider closing stale Claude/VS Code sessions"
    fi
    rm -f "$cleanup_probe" 2>/dev/null || true
  else
    ok "MCP process count" "$mcp_processes running"
  fi
fi
echo

if [ "$fails" -gt 0 ]; then
  status "FAIL" "audit summary" "$fails fail(s), $warns warning(s)"
  exit 1
fi

if [ "$warns" -gt 0 ]; then
  status "WARN" "audit summary" "$warns warning(s), no hard failures"
else
  status "OK" "audit summary" "clean"
fi
