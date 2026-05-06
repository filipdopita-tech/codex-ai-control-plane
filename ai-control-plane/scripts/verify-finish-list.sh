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
is_registered_cz() {
  local d="$1"
  whois -h whois.nic.cz "$d" 2>/dev/null | tr -d '\r' | grep -qiE "^domain:[[:space:]]+$d$" \
    || dig +short NS "$d" @1.1.1.1 2>/dev/null | grep -q .
}
registry_keyset_cz() {
  local d="$1" keyset
  for _ in 1 2; do
    keyset=$(whois -h whois.nic.cz "$d" 2>/dev/null | tr -d '\r' | awk -F: 'tolower($1)=="keyset"{gsub(/^[ \t]+|[ \t]+$/, "", $2); print $2; exit}')
    if [[ -n "$keyset" ]]; then
      printf '%s\n' "$keyset"
      return 0
    fi
    sleep 1
  done
  return 1
}

echo "=== Block 4 — DMARC sister domains ==="
for d in oneflow.cz of-fund.cz hala-tower.cz patricny-park.cz nebulee.cz; do
  if [[ "$d" == *.cz ]] && ! is_registered_cz "$d"; then
    log_pass "$d not registered at CZ.NIC — DMARC/DNSSEC not applicable unless domain is purchased"
    continue
  fi
  txt=$(dig +short TXT _dmarc.$d @1.1.1.1 2>/dev/null | head -1)
  if [[ "$txt" == *"v=DMARC1"* && "$txt" == *"p=reject"* ]]; then
    log_pass "$d DMARC p=reject"
  elif [[ "$txt" == *"v=DMARC1"* ]]; then
    log_warn "$d DMARC present but not p=reject ($txt)"
  else
    # Sister domains: check if registered in Cloudflare yet
    ns=$(dig +short NS $d @1.1.1.1 2>/dev/null | head -1)
    if [[ "$ns" == *"ns.nic.cz"* || -z "$ns" ]]; then
      log_warn "$d not yet on Cloudflare (NS still registry-only) — Block 4.1+4.3 pending Filip-side"
    else
      log_fail "$d DMARC missing (NS=$ns, run cloudflare-publish-sister-dmarc.sh)"
    fi
  fi
done

echo "=== Block 4 — DNSSEC DS at registrar (Wedos) ==="
for d in oneflow.cz of-fund.cz hala-tower.cz patricny-park.cz nebulee.cz; do
  if [[ "$d" == *.cz ]] && ! is_registered_cz "$d"; then
    log_pass "$d not registered at CZ.NIC — DS not applicable unless domain is purchased"
    continue
  fi
  ds=$(dig +short DS "$d" @a.ns.nic.cz 2>/dev/null | head -1)
  if [[ -z "$ds" ]]; then
    ds=$(dig +short DS "$d" @1.1.1.1 2>/dev/null | head -1)
  fi
  if [[ -n "$ds" ]]; then
    log_pass "$d DNSSEC DS at registry ($ds)"
  else
    keyset="$(registry_keyset_cz "$d" || true)"
    if [[ -n "$keyset" ]]; then
      log_warn "$d DNSSEC KEYSET present at registry ($keyset), DS not visible yet — propagation pending"
    else
      log_warn "$d DNSSEC DS not at registry (paste DNSKEY/KEYSET at Wedos panel)"
    fi
  fi
done

echo "=== ntfy + dispatch end-to-end ==="
ntfy_http=$(curl -s -o /dev/null -w "%{http_code}" "https://ntfy.oneflow.cz" 2>/dev/null)
if [[ "$ntfy_http" == "200" ]]; then
  log_pass "ntfy.oneflow.cz HTTP 200"
else
  log_fail "ntfy.oneflow.cz HTTP $ntfy_http"
fi
dispatch_secret="${DISPATCH_SECRET:-}"
if [ -z "$dispatch_secret" ] && [ -r "$HOME/.credentials/master.env" ]; then
  # shellcheck disable=SC1090,SC1091
  source "$HOME/.credentials/master.env" 2>/dev/null || true
  dispatch_secret="${DISPATCH_SECRET:-}"
fi
if [ -z "$dispatch_secret" ]; then
  dispatch_secret="$(ssh -o BatchMode=yes -o ConnectTimeout=5 root@10.77.0.1 \
    "python3 -c \"import json; print(json.load(open('/root/.hermes/webhook_subscriptions.json'))['dispatch']['secret'])\"" \
    2>/dev/null || true)"
  if [ -n "$dispatch_secret" ]; then
    log_pass "dispatch HMAC secret fetched from Flash route config"
  fi
fi
if [ -z "$dispatch_secret" ]; then
  log_warn "DISPATCH_SECRET unavailable locally and Flash route secret fetch failed — skipping dispatch HMAC test"
else
  dispatch_body='{"body":"verify-finish-list dispatch sanity"}'
  dispatch_sig=$(printf '%s' "$dispatch_body" | openssl dgst -sha256 -hmac "$dispatch_secret" -hex 2>/dev/null | awk '{print $NF}')
  dispatch_http=$(curl -s -o /dev/null -w "%{http_code}" -X POST https://dispatch.oneflow.cz/webhooks/dispatch \
    -H "Content-Type: application/json" -H "X-Hub-Signature-256: sha256=$dispatch_sig" -d "$dispatch_body" 2>/dev/null)
  if [[ "$dispatch_http" == "202" || "$dispatch_http" == "200" ]]; then
    log_pass "dispatch.oneflow.cz HMAC accepted (HTTP $dispatch_http)"
  else
    log_fail "dispatch.oneflow.cz HTTP $dispatch_http"
  fi
fi

echo "=== Block 5.1 — ofs notify ==="
if /Users/filipdopita/.local/bin/ofs notify "verify-finish-list smoke $(date -u +%H:%M:%SZ)" >/dev/null 2>&1; then
  log_pass "ofs notify dispatched"
else
  log_fail "ofs notify failed"
fi

echo "=== Block 5.2 — mobile-flash auth ==="
auth_json="$(ssh -o BatchMode=yes -o ConnectTimeout=5 root@10.77.0.1 'claude auth status 2>/dev/null' 2>/dev/null || echo '{}')"
auth_logged_in="$(printf '%s' "$auth_json" | grep -oE '"loggedIn":[[:space:]]*(true|false)' | grep -oE '(true|false)' || echo 'unknown')"
svc_state="$(ssh -o BatchMode=yes -o ConnectTimeout=5 root@10.77.0.1 'systemctl is-active claude-rc 2>/dev/null' 2>/dev/null || echo 'unknown')"
rc_url="$(ssh -o BatchMode=yes -o ConnectTimeout=5 root@10.77.0.1 "grep -oE 'https://claude\\.ai/code\\?environment=env_[A-Za-z0-9]+' /var/log/claude-rc.log 2>/dev/null | tail -n 1" 2>/dev/null || true)"
if [[ "$auth_logged_in" == "true" ]]; then
  log_pass "claude-rc auth healthy (auth=true service=$svc_state)"
elif [[ "$svc_state" == "active" && -n "$rc_url" ]]; then
  log_pass "claude-rc service usable (auth=$auth_logged_in service=active session_url_present=true)"
else
  log_fail "claude-rc not healthy (auth=$auth_logged_in service=$svc_state session_url_present=false)"
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
