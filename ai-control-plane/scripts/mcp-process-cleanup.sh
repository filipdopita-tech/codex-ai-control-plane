#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: mcp-process-cleanup.sh [--apply] [--older-than-min N] [--kind KIND]

Safely identifies stale duplicate MCP-like processes and, only with --apply,
terminates the selected PIDs.

Default mode is dry-run. It never kills:
  - the newest process pair per MCP kind
  - processes younger than --older-than-min
  - anything outside the known MCP command patterns

Options:
  --apply             actually terminate selected PIDs (TERM, then KILL if needed)
  --older-than-min N  minimum process age in minutes (default 30)
  --kind KIND         restrict cleanup to one kind:
                     code-review-graph, obsidian-mcp, context7-mcp,
                     stitch-mcp, filesystem-mcp, scrapling-mcp,
                     memory-search-mcp
  --help             show this help

Recommended flow:
  1. ./mcp-process-cleanup.sh
  2. inspect selected PIDs
  3. ./mcp-process-cleanup.sh --apply --kind code-review-graph
EOF
}

APPLY=0
OLDER_THAN_MIN=30
ONLY_KIND=""

while [ $# -gt 0 ]; do
  case "${1:-}" in
    --apply)
      APPLY=1
      shift
      ;;
    --older-than-min)
      OLDER_THAN_MIN="${2:-}"
      shift 2
      ;;
    --kind)
      ONLY_KIND="${2:-}"
      shift 2
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

case "$OLDER_THAN_MIN" in
  ''|*[!0-9]*)
    echo "Invalid --older-than-min: $OLDER_THAN_MIN" >&2
    exit 1
    ;;
esac

case "$ONLY_KIND" in
  ""|code-review-graph|obsidian-mcp|context7-mcp|stitch-mcp|filesystem-mcp|scrapling-mcp|memory-search-mcp) ;;
  *)
    echo "Invalid --kind: $ONLY_KIND" >&2
    exit 1
    ;;
esac

MIN_AGE=$((OLDER_THAN_MIN * 60))

tmp="$(mktemp -t mcp-cleanup.XXXXXX)"
trap 'rm -f "$tmp"' EXIT

ps -axo pid=,etime=,command= 2>/dev/null | awk -v min_age="$MIN_AGE" -v only_kind="$ONLY_KIND" '
function etime_seconds(raw, parts, n, days, h, m, s, rest) {
  days=0
  rest=raw
  if (index(raw, "-") > 0) {
    split(raw, parts, "-")
    days=parts[1]
    rest=parts[2]
  }
  n=split(rest, parts, ":")
  if (n == 3) {
    h=parts[1]; m=parts[2]; s=parts[3]
  } else if (n == 2) {
    h=0; m=parts[1]; s=parts[2]
  } else {
    h=0; m=0; s=parts[1]
  }
  return (days * 86400) + (h * 3600) + (m * 60) + s
}
function kind_for(cmd) {
  if (cmd ~ /code-review-graph serve/) return "code-review-graph"
  if (cmd ~ /obsidian-mcp/) return "obsidian-mcp"
  if (cmd ~ /context7-mcp/) return "context7-mcp"
  if (cmd ~ /stitch-mcp/) return "stitch-mcp"
  if (cmd ~ /mcp-server-filesystem/) return "filesystem-mcp"
  if (cmd ~ /scrapling mcp/) return "scrapling-mcp"
  if (cmd ~ /memory-search-mcp/) return "memory-search-mcp"
  return ""
}
{
  pid=$1
  etime=$2
  cmd=$0
  sub(/^[[:space:]]*[0-9]+[[:space:]]+[^[:space:]]+[[:space:]]+/, "", cmd)
  kind=kind_for(cmd)
  if (kind == "") next
  if (only_kind != "" && kind != only_kind) next

  age=etime_seconds(etime)
  if (age < min_age) next

  count[kind] += 1
  pids[kind, count[kind]]=pid
  ages[kind, count[kind]]=age
  cmds[kind, count[kind]]=cmd
}
END {
  for (kind in count) {
    # Keep the two newest matching processes per kind. Older duplicates are cleanup candidates.
    keep=2
    for (i=1; i<=count[kind]; i++) {
      for (j=i+1; j<=count[kind]; j++) {
        if (ages[kind, j] < ages[kind, i]) {
          ta=ages[kind, i]; ages[kind, i]=ages[kind, j]; ages[kind, j]=ta
          tp=pids[kind, i]; pids[kind, i]=pids[kind, j]; pids[kind, j]=tp
          tc=cmds[kind, i]; cmds[kind, i]=cmds[kind, j]; cmds[kind, j]=tc
        }
      }
    }
    for (i=keep+1; i<=count[kind]; i++) {
      printf "%s\t%s\t%d\t%s\n", kind, pids[kind, i], int(ages[kind, i] / 60), cmds[kind, i]
    }
  }
}
' > "$tmp"

echo "MCP process cleanup"
echo "==================="
echo "Mode: $([ "$APPLY" -eq 1 ] && echo apply || echo dry-run)"
echo "Older than: ${OLDER_THAN_MIN} min"
[ -n "$ONLY_KIND" ] && echo "Kind: $ONLY_KIND"
echo

if [ ! -s "$tmp" ]; then
  echo "No stale duplicate MCP processes selected."
  exit 0
fi

printf "%-22s %-8s %-10s %s\n" "kind" "pid" "age_min" "command"
awk -F '\t' '{printf "%-22s %-8s %-10s %.120s\n", $1, $2, $3, $4}' "$tmp"
echo

if [ "$APPLY" -eq 0 ]; then
  echo "Dry-run only. Re-run with --apply to terminate selected PIDs."
  exit 0
fi

while IFS=$'\t' read -r kind pid age cmd; do
  if kill -0 "$pid" 2>/dev/null; then
    echo "TERM $pid ($kind, ${age}min)"
    kill -TERM "$pid" 2>/dev/null || true
  fi
done < "$tmp"

sleep 2

while IFS=$'\t' read -r kind pid age cmd; do
  if kill -0 "$pid" 2>/dev/null; then
    echo "KILL $pid ($kind, still running)"
    kill -KILL "$pid" 2>/dev/null || true
  fi
done < "$tmp"

echo
echo "Cleanup complete. Re-run mcp-process-audit.sh to verify."
