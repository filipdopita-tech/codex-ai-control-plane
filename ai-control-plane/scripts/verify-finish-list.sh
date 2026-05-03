#!/usr/bin/env bash
# verify-finish-list.sh — re-runs Block 5 smoke tests from FINISH-LIST-2026-05-03.md
# Usage: ./verify-finish-list.sh [--quick]
#   --quick   Skip alert smoke + bridge round-trip (no iPhone push)
#
# Exits non-zero if any check fails. Designed for cron / SessionStart hook.

set -uo pipefail
QUICK=${1:-}
PASS=0
FAIL=0
WARN=0

log_pass() { echo "  [PASS] $*"; PASS=$((PASS+1)); }
log_fail() { echo "  [FAIL] $*"; FAIL=$((FAIL+1)); }
log_warn() { echo "  [WARN] $*"; WARN=$((WARN+1)); }

echo "=== Block 4 — DMARC sister domains ==="
for d in oneflow.cz of-fund.cz hala-tower.cz patricny-park.cz nebulee.cz; do
  txt=$(dig +short TXT _dmarc.$d @1.1.1.1 2>/dev/null | head -1)
  if [[ "$txt" == *"v=DMARC1"* && "$txt" == *"p=reject"* ]]; then
    log_pass "$d DMARC p=reject"
  elif [[ "$txt" == *"v=DMARC1"* ]]; then
    log_warn "$d DMARC present but not p=reject ($txt)"
  else
    log_fail "$d DMARC missing"
  fi
done

echo "=== Block 5.1 — ofs notify ==="
if /Users/filipdopita/.local/bin/ofs notify "verify-finish-list smoke $(date -u +%H:%M:%SZ)" >/dev/null 2>&1; then
  log_pass "ofs notify dispatched"
else
  log_fail "ofs notify failed"
fi

echo "=== Block 5.2 — mobile-flash auth ==="
auth=$(/Users/filipdopita/.local/bin/ofs mobile-flash check-auth --verbose 2>&1 | head -1)
if [[ "$auth" == *"auth=true"* ]]; then
  log_pass "claude-rc auth healthy ($auth)"
else
  log_fail "claude-rc auth not healthy ($auth)"
fi

echo "=== Block 5.2 — observability stack ==="
ps_out=$(ssh -o BatchMode=yes -o ConnectTimeout=5 root@10.77.0.1 'cd /opt/observability && docker compose ps --format "{{.Service}} {{.Status}}"' 2>/dev/null)
for svc in prometheus alertmanager loki promtail grafana cadvisor node-exporter; do
  if echo "$ps_out" | grep -q "^$svc Up"; then
    log_pass "container $svc Up"
  else
    log_fail "container $svc not Up"
  fi
done

if [[ "$QUICK" != "--quick" ]]; then
  echo "=== Block 5.4 — alertmanager-ntfy bridge round-trip ==="
  alert_payload='{"alerts":[{"labels":{"alertname":"verify_finish_list","severity":"info","instance":"flash"},"annotations":{"summary":"verify-finish-list smoke ok"},"status":"firing"}]}'
  http=$(ssh -o BatchMode=yes -o ConnectTimeout=5 root@10.77.0.1 "curl -s -o /dev/null -w '%{http_code}' -X POST http://172.30.0.1:9094/alert -H 'Content-Type: application/json' -d '$alert_payload'" 2>/dev/null)
  if [[ "$http" == "200" ]]; then
    log_pass "bridge POST /alert returned 200 (push fired to ntfy)"
  else
    log_fail "bridge POST /alert returned $http"
  fi
fi

echo "=== Backup textfile metric (oneflow_backup_last_success) ==="
ts=$(ssh -o BatchMode=yes -o ConnectTimeout=5 root@10.77.0.1 "curl -s http://127.0.0.1:9090/api/v1/query?query=oneflow_backup_last_success_timestamp_seconds 2>/dev/null | python3 -c 'import sys,json; d=json.load(sys.stdin); r=d.get(\"data\",{}).get(\"result\",[]); print(r[0][\"value\"][1] if r else \"\")'" 2>/dev/null)
if [[ -n "$ts" ]]; then
  age_h=$(echo "($(date +%s) - $ts) / 3600" | bc 2>/dev/null)
  if [[ -n "$age_h" && "$age_h" -lt 25 ]]; then
    log_pass "backup metric $age_h h ago (<25h, BackupStale will not fire)"
  else
    log_warn "backup metric $age_h h ago (>=25h, BackupStale would fire)"
  fi
else
  log_warn "backup metric not yet scraped (run /usr/local/bin/oneflow-backup.sh once on Flash)"
fi

echo "=== Summary ==="
echo "PASS=$PASS FAIL=$FAIL WARN=$WARN"
if [[ "$FAIL" -gt 0 ]]; then
  exit 1
fi
exit 0
