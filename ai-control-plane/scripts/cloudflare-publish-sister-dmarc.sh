#!/usr/bin/env bash
# cloudflare-publish-sister-dmarc.sh — publishes DMARC + SPF + DNSSEC for 4 sister domains
# Block 4 of FINISH-LIST-2026-05-03.md (Cloudflare path)
#
# Prerequisite: cloudflare-add-sister-zones.sh ran successfully + Wedos NS delegation done.
# Idempotent: re-running just updates existing TXT records.

set -euo pipefail

CF_TOKEN="${CF_API_TOKEN:-}"
if [[ -z "$CF_TOKEN" ]]; then
  if [[ -f /root/.credentials/master.env ]]; then
    CF_TOKEN=$(grep "^CF_API_TOKEN=" /root/.credentials/master.env | cut -d= -f2)
  fi
  if [[ -z "$CF_TOKEN" ]]; then
    echo "ERROR: CF_API_TOKEN not set" >&2; exit 1
  fi
fi

DOMAINS=(of-fund.cz hala-tower.cz patricny-park.cz nebulee.cz)
DMARC_VALUE="v=DMARC1; p=reject; rua=mailto:dmarc@oneflow.cz; ruf=mailto:dmarc@oneflow.cz; fo=1; pct=100; adkim=s; aspf=s"
SPF_VALUE="v=spf1 -all"  # No mail sent from these domains; reject all (anti-spoof)

publish_txt() {
  local zone_id="$1" name="$2" content="$3" record_type="${4:-TXT}"
  # Find existing record
  existing_id=$(curl -s -H "Authorization: Bearer $CF_TOKEN" \
    "https://api.cloudflare.com/client/v4/zones/$zone_id/dns_records?type=$record_type&name=$name" | \
    python3 -c 'import sys,json; r=json.load(sys.stdin).get("result",[]); print(r[0]["id"] if r else "")')
  payload=$(python3 -c "import json; print(json.dumps({'type':'$record_type','name':'$name','content':'$content','ttl':3600}))")
  if [[ -n "$existing_id" ]]; then
    curl -s -X PUT -H "Authorization: Bearer $CF_TOKEN" -H "Content-Type: application/json" \
      "https://api.cloudflare.com/client/v4/zones/$zone_id/dns_records/$existing_id" \
      -d "$payload" | python3 -c 'import sys,json; d=json.load(sys.stdin); print("  · updated " if d.get("success") else "  ✗ FAIL: ", d.get("errors"))'
  else
    curl -s -X POST -H "Authorization: Bearer $CF_TOKEN" -H "Content-Type: application/json" \
      "https://api.cloudflare.com/client/v4/zones/$zone_id/dns_records" \
      -d "$payload" | python3 -c 'import sys,json; d=json.load(sys.stdin); print("  ✓ created " if d.get("success") else "  ✗ FAIL: ", d.get("errors"))'
  fi
}

enable_dnssec() {
  local zone_id="$1" zone_name="$2"
  resp=$(curl -s -X PATCH -H "Authorization: Bearer $CF_TOKEN" -H "Content-Type: application/json" \
    "https://api.cloudflare.com/client/v4/zones/$zone_id/dnssec" \
    -d '{"status":"active"}')
  if echo "$resp" | grep -q '"success":true'; then
    ds=$(echo "$resp" | python3 -c 'import sys,json; print(json.load(sys.stdin)["result"]["ds"])')
    echo "  ✓ DNSSEC active. Submit DS at registrar (Wedos):"
    echo "    $ds"
  else
    err=$(echo "$resp" | python3 -c 'import sys,json; print(json.load(sys.stdin).get("errors"))')
    echo "  ✗ DNSSEC enable failed: $err"
  fi
}

for d in "${DOMAINS[@]}"; do
  echo "=== $d ==="
  zone_id=$(curl -s -H "Authorization: Bearer $CF_TOKEN" \
    "https://api.cloudflare.com/client/v4/zones?name=$d" | \
    python3 -c 'import sys,json; r=json.load(sys.stdin).get("result",[]); print(r[0]["id"] if r else "")')
  if [[ -z "$zone_id" ]]; then
    echo "  ✗ zone not found in Cloudflare; run cloudflare-add-sister-zones.sh first"
    continue
  fi
  echo "  zone_id=$zone_id"
  echo "  → DMARC TXT _dmarc.$d"
  publish_txt "$zone_id" "_dmarc.$d" "$DMARC_VALUE"
  echo "  → SPF TXT @ ($d)"
  publish_txt "$zone_id" "$d" "$SPF_VALUE"
  echo "  → DNSSEC enable"
  enable_dnssec "$zone_id" "$d"
done

echo ""
echo "=== Verify post-publish (~10 min DNS prop) ==="
echo "for d in ${DOMAINS[*]}; do echo -n \"\$d DMARC: \"; dig +short TXT _dmarc.\$d @1.1.1.1 | head -1; done"
echo ""
echo "=== Final verify-finish-list ==="
echo "~/Desktop/Codex/ai-control-plane/scripts/verify-finish-list.sh"
