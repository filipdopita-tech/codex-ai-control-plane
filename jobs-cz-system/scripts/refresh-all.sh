#!/usr/bin/env bash
# refresh-all.sh — denní cron entry. Spouští všechny saved searches,
# loguje do /var/log/jobs-cz-refresh.log, ntfy push při selhání.
set -uo pipefail

LOG=/var/log/jobs-cz-refresh.log
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")"/.. && pwd)"
TS="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

mkdir -p "$(dirname "$LOG")"
{
    echo ""
    echo "=== $TS — refresh-all start ==="
    "$ROOT/jobs.sh" run-all
    rc=$?
    echo "=== $TS — refresh-all done (rc=$rc) ==="

    # Master leads merge + ARES enrichment + stats dashboard (Obsidian sync)
    "$ROOT/jobs.sh" export-all   || echo "[WARN] export-all failed"
    "$ROOT/jobs.sh" enrich-today --limit 30 || echo "[WARN] enrich-today failed"
    "$ROOT/jobs.sh" stats > /tmp/jobs-cz-stats.md 2>&1 || echo "[WARN] stats failed"
    exit $rc
} 2>&1 | tee -a "$LOG"
