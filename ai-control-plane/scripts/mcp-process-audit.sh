#!/usr/bin/env bash
set -euo pipefail

echo "MCP process audit"
echo "================="
echo

patterns='obsidian-mcp|code-review-graph serve|context7-mcp|stitch-mcp|mcp-server-filesystem|scrapling mcp|memory-search-mcp'

if ! ps_rows="$(ps -axo pid,lstart,pcpu,pmem,command 2>/dev/null | egrep "$patterns" | egrep -v 'egrep|mcp-process-audit|ps -axo')"; then
  echo "No matching MCP processes found."
  exit 0
fi

printf "%s\n" "$ps_rows" | awk '
  /obsidian-mcp/ {kind="obsidian-mcp"}
  /code-review-graph serve/ {kind="code-review-graph"}
  /context7-mcp/ {kind="context7-mcp"}
  /stitch-mcp/ {kind="stitch-mcp"}
  /mcp-server-filesystem/ {kind="filesystem-mcp"}
  /scrapling mcp/ {kind="scrapling-mcp"}
  /memory-search-mcp/ {kind="memory-search-mcp"}
  {
    count[kind] += 1
    # ps columns are: pid lstart(5 fields) pcpu pmem command...
    # Command arguments can contain spaces, so do not infer CPU/RAM from NF.
    cpu[kind] += $7
    mem[kind] += $8
  }
  END {
    printf "%-24s %6s %8s %8s\n", "kind", "count", "cpu%", "mem%"
    for (k in count) {
      printf "%-24s %6d %8.1f %8.1f\n", k, count[k], cpu[k], mem[k]
    }
  }
'

echo
echo "Process detail:"
printf "%s\n" "$ps_rows" | sed -n '1,80p'
echo

total="$(printf "%s\n" "$ps_rows" | wc -l | tr -d ' ')"
if [ "$total" -gt 20 ]; then
  echo "WARN: $total MCP-like processes are running. This can increase swap and context/tool overhead."
  echo "Use this audit before manually stopping stale Claude/VS Code sessions."
else
  echo "OK: $total MCP-like processes running."
fi
