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

python3 - "$MIN_AGE" "$ONLY_KIND" > "$tmp" <<'PY'
import re
import subprocess
import sys
from collections import defaultdict

min_age = int(sys.argv[1])
only_kind = sys.argv[2]

PATTERNS = [
    ("code-review-graph", re.compile(r"code-review-graph serve")),
    ("obsidian-mcp", re.compile(r"obsidian-mcp")),
    ("context7-mcp", re.compile(r"context7-mcp")),
    ("stitch-mcp", re.compile(r"stitch-mcp")),
    ("filesystem-mcp", re.compile(r"mcp-server-filesystem")),
    ("scrapling-mcp", re.compile(r"scrapling mcp")),
    ("memory-search-mcp", re.compile(r"memory-search-mcp")),
]

def etime_seconds(raw: str) -> int:
    days = 0
    rest = raw
    if "-" in raw:
        day_s, rest = raw.split("-", 1)
        days = int(day_s or "0")
    parts = [int(p or "0") for p in rest.split(":")]
    if len(parts) == 3:
        h, m, s = parts
    elif len(parts) == 2:
        h, m, s = 0, parts[0], parts[1]
    else:
        h, m, s = 0, 0, parts[0]
    return days * 86400 + h * 3600 + m * 60 + s

def kind_for(cmd: str) -> str:
    for kind, pattern in PATTERNS:
        if pattern.search(cmd):
            return kind
    return ""

groups = defaultdict(list)
try:
    ps_out = subprocess.check_output(
        ["ps", "-axo", "pid=,etime=,command="],
        text=True,
        stderr=subprocess.DEVNULL,
    )
except Exception:
    ps_out = ""

for line in ps_out.splitlines():
    line = line.strip()
    if not line:
        continue
    parts = line.split(None, 2)
    if len(parts) < 3:
        continue
    pid, etime, cmd = parts
    kind = kind_for(cmd)
    if not kind or (only_kind and kind != only_kind):
        continue
    try:
        age = etime_seconds(etime)
    except Exception:
        continue
    groups[kind].append((age, pid, cmd))

for kind, rows in groups.items():
    # Keep the two newest processes per kind regardless of age threshold.
    rows.sort(key=lambda row: row[0])
    for age, pid, cmd in rows[2:]:
        if age >= min_age:
            print(f"{kind}\t{pid}\t{age // 60}\t{cmd}")
PY

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

while IFS=$'\t' read -r kind pid age _cmd; do
  if kill -0 "$pid" 2>/dev/null; then
    echo "TERM $pid ($kind, ${age}min)"
    kill -TERM "$pid" 2>/dev/null || true
  fi
done < "$tmp"

sleep 2

while IFS=$'\t' read -r kind pid age _cmd; do
  if kill -0 "$pid" 2>/dev/null; then
    echo "KILL $pid ($kind, still running)"
    kill -KILL "$pid" 2>/dev/null || true
  fi
done < "$tmp"

echo
echo "Cleanup complete. Re-run mcp-process-audit.sh to verify."
