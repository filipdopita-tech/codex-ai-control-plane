#!/usr/bin/env bash
# ofs metrics — performance dashboard z audit logů
# Anti-halucinace: vše počítané z reálných JSONL logů, žádné estimates.
set -euo pipefail

LOG_DIR="$HOME/.claude/logs"
OFS_LOG="$LOG_DIR/ofs.jsonl"
HEAL_LOG="$LOG_DIR/ofs-heal.jsonl"
USAGE_LOG="$LOG_DIR/usage-tracker.jsonl"
RESOURCE_LOG="$LOG_DIR/resource-monitor.jsonl"

usage() {
  cat <<'EOF'
Usage: ofs metrics [--days N] [--json]

Performance dashboard z reálných audit logů:
  - ofs.jsonl       — všechny ofs CLI calls, kolik volání kterého actionu
  - ofs-heal.jsonl  — heal events, success rate, MTTR
  - usage-tracker   — Codex usage est., handoff counts
  - resource-monitor — Mac swap/load trends (last 24h)

Defaults: posledních 7 dnů, human-readable output.

Příklady:
  ofs metrics
  ofs metrics --days 1
  ofs metrics --json
EOF
  exit "${1:-1}"
}

DAYS=7
JSON=0
while [ $# -gt 0 ]; do
  case "${1:-}" in
    --help|-h) usage 0 ;;
    --days) DAYS="${2:-7}"; shift 2 ;;
    --json) JSON=1; shift ;;
    *) shift ;;
  esac
done

# Cutoff date (UTC ISO8601 prefix YYYY-MM-DD)
if date -u -v-${DAYS}d '+%Y-%m-%d' >/dev/null 2>&1; then
  CUTOFF=$(date -u -v-${DAYS}d '+%Y-%m-%d')
else
  CUTOFF=$(date -u -d "-${DAYS} days" '+%Y-%m-%d' 2>/dev/null || echo "2026-01-01")
fi

color() {
  case "$1" in
    bold) printf "\033[1m%s\033[0m" "$2" ;;
    green) printf "\033[32m%s\033[0m" "$2" ;;
    yellow) printf "\033[33m%s\033[0m" "$2" ;;
    blue) printf "\033[34m%s\033[0m" "$2" ;;
    dim) printf "\033[2m%s\033[0m" "$2" ;;
    *) printf "%s" "$2" ;;
  esac
}

# Helper: filter JSONL since CUTOFF (lexicographic ISO compare works)
filter_recent() {
  local f="$1"
  [ -f "$f" ] || { echo ""; return; }
  awk -v cutoff="$CUTOFF" -F'"' '
    /"ts":"/ {
      for (i=1; i<=NF; i++) if ($i == "ts") { ts=$(i+2); break }
      if (ts >= cutoff) print $0
    }
  ' "$f"
}

# Helper: count matches without grep -c trap (returns single integer always)
count_match() {
  local pattern="$1" input="$2"
  printf '%s\n' "$input" | awk -v p="$pattern" 'BEGIN{n=0} $0 ~ p {n++} END{print n+0}'
}

if [ "$JSON" -eq 1 ]; then
  # ── JSON OUTPUT ──
  RECENT_OFS=$(filter_recent "$OFS_LOG")
  RECENT_HEAL=$(filter_recent "$HEAL_LOG")
  TOTAL_OFS=$(count_match '^\{' "$RECENT_OFS")
  TOTAL_HEAL=$(count_match '^\{' "$RECENT_HEAL")
  TOP_ACTIONS=$(printf '%s\n' "$RECENT_OFS" | sed -nE 's/.*"action":"([^"]+)".*/\1/p' | sort | uniq -c | sort -rn | head -5 | awk '{printf "{\"action\":\"%s\",\"count\":%d},", $2, $1}' | sed 's/,$//')
  cat <<EOF
{
  "window_days": $DAYS,
  "cutoff": "$CUTOFF",
  "ofs_calls_total": $TOTAL_OFS,
  "heal_events_total": $TOTAL_HEAL,
  "top_actions": [$TOP_ACTIONS]
}
EOF
  exit 0
fi

# ── HUMAN OUTPUT ──
echo
color bold "ofs metrics — last $DAYS days (since $CUTOFF UTC)"; echo
echo "================================================="
echo

# 1. OFS CLI USAGE
color blue "[ofs CLI usage]"; echo
RECENT_OFS=$(filter_recent "$OFS_LOG")
TOTAL=$(count_match '^\{' "$RECENT_OFS")
echo "  Total calls:  $TOTAL"
if [ "$TOTAL" -gt 0 ]; then
  echo "  Top actions:"
  printf '%s\n' "$RECENT_OFS" | sed -nE 's/.*"action":"([^"]+)".*/\1/p' | sort | uniq -c | sort -rn | head -5 | awk '{printf "    %-15s %d\n", $2, $1}'
  STATUS_OK=$(count_match '"status":"ok"' "$RECENT_OFS")
  STATUS_ERR=$(count_match '"status":"(error|fail|down)"' "$RECENT_OFS")
  SUCCESS_PCT=$(awk "BEGIN { printf \"%.1f\", ($STATUS_OK / $TOTAL) * 100 }")
  echo "  Success: $STATUS_OK ok / $STATUS_ERR error → ${SUCCESS_PCT}%"
fi
echo

# 2. HEAL EVENTS
color blue "[heal events]"; echo
RECENT_HEAL=$(filter_recent "$HEAL_LOG")
HEAL_TOTAL=$(count_match '^\{' "$RECENT_HEAL")
if [ "$HEAL_TOTAL" -eq 0 ]; then
  color dim "  (no heal events — services healthy)"; echo
else
  echo "  Total restarts attempted: $HEAL_TOTAL"
  RECOVERED=$(count_match '"after":"active"' "$RECENT_HEAL")
  echo "  Recovered: $RECOVERED / $HEAL_TOTAL"
  echo "  Most-restarted services:"
  printf '%s\n' "$RECENT_HEAL" | sed -nE 's/.*"service":"([^"]+)".*/\1/p' | sort | uniq -c | sort -rn | head -3 | awk '{printf "    %-25s %d×\n", $2, $1}'
fi
echo

# 3. RESOURCE TRENDS (Mac)
color blue "[mac resource trends]"; echo
if [ -f "$RESOURCE_LOG" ]; then
  RECENT_RES=$(filter_recent "$RESOURCE_LOG")
  if [ -n "$RECENT_RES" ]; then
    AVG_LOAD=$(printf '%s\n' "$RECENT_RES" | sed -nE 's/.*"load_1":([^,}]+).*/\1/p' | awk '{ s+=$1; n++ } END { if (n>0) printf "%.2f", s/n }')
    AVG_SWAP=$(printf '%s\n' "$RECENT_RES" | sed -nE 's/.*"swap_pct":([^,}]+).*/\1/p' | awk '{ s+=$1; n++ } END { if (n>0) printf "%.0f", s/n }')
    MAX_SWAP=$(printf '%s\n' "$RECENT_RES" | sed -nE 's/.*"swap_pct":([^,}]+).*/\1/p' | sort -rn | head -1)
    echo "  Avg load (1min): ${AVG_LOAD:-n/a}"
    echo "  Avg swap %:      ${AVG_SWAP:-n/a}"
    echo "  Peak swap %:     ${MAX_SWAP:-n/a}"
    if [ -n "$MAX_SWAP" ] && awk "BEGIN { exit !($MAX_SWAP > 80) }"; then
      color yellow "  ⚠ Peak swap >80% — consider 'ofs swap' offload"; echo
    fi
  else
    color dim "  (no recent samples)"; echo
  fi
else
  color dim "  (resource-monitor.jsonl not found)"; echo
fi
echo

# 4. HANDOFF VOLUME
color blue "[handoff volume]"; echo
HANDOFF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/handoffs"
if [ -d "$HANDOFF_DIR" ]; then
  if date -u -v-${DAYS}d '+%Y%m%d' >/dev/null 2>&1; then
    CUTOFF_COMPACT=$(date -u -v-${DAYS}d '+%Y%m%d')
  else
    CUTOFF_COMPACT=$(date -u -d "-${DAYS} days" '+%Y%m%d' 2>/dev/null || echo "20260101")
  fi
  RECENT_HANDOFFS=$(ls "$HANDOFF_DIR"/*.md 2>/dev/null | awk -F/ '{print $NF}' | awk -v c="$CUTOFF_COMPACT" '$1 >= c' | wc -l | tr -d ' ')
  TOTAL_HANDOFFS=$(ls "$HANDOFF_DIR"/*.md 2>/dev/null | wc -l | tr -d ' ')
  echo "  Recent ($DAYS days): $RECENT_HANDOFFS"
  echo "  Total in folder:     $TOTAL_HANDOFFS"
  if [ "$TOTAL_HANDOFFS" -gt 200 ]; then
    color yellow "  ⚠ folder >200 entries — consider 'cleanup-handoffs.sh'"; echo
  fi
else
  color dim "  (handoffs dir not found)"; echo
fi
echo

# 5. COST ESTIMATE (Codex usage)
color blue "[codex usage estimate]"; echo
if [ -f "$USAGE_LOG" ]; then
  RECENT_USAGE=$(filter_recent "$USAGE_LOG")
  USAGE_COUNT=$(count_match '^\{' "$RECENT_USAGE")
  echo "  Codex calls:  $USAGE_COUNT"
else
  color dim "  (usage-tracker.jsonl not found)"; echo
fi
echo

echo "================================================="
color dim "Tip: --days 1 pro denní snapshot, --json pro programatic"; echo
