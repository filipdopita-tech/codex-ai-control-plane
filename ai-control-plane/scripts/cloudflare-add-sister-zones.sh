#!/usr/bin/env bash
# cloudflare-add-sister-zones.sh — adds 4 sister domains to Cloudflare zone
# Block 4 of FINISH-LIST-2026-05-03.md (Cloudflare path, replaces Wedos panel)
#
# Prerequisite: CF_API_TOKEN with permission "Account.Zone: Edit" on Filipdopit@gmail.com's Account
# (current scoped token only has Zone-level edit on oneflow.cz; needs upgrade once)
#
# Token upgrade URL: https://dash.cloudflare.com/profile/api-tokens
#   Edit token → Permissions → Add: Account / Zone / Edit
#   Resources → Include / Specific account / Filipdopit@gmail.com's Account
#   Save → reuse same token, no re-deploy needed (master.env already has CF_API_TOKEN)
#
# After token upgrade, run this script. It is idempotent (skips zones already present).

set -euo pipefail

CF_TOKEN="${CF_API_TOKEN:-}"
ACCOUNT_ID="4a6b6588a7ed0a2280ff7ee226da6e96"  # Filipdopit@gmail.com's Account

if [[ -z "$CF_TOKEN" ]]; then
  if [[ -f /root/.credentials/master.env ]]; then
    CF_TOKEN=$(grep "^CF_API_TOKEN=" /root/.credentials/master.env | cut -d= -f2)
  fi
  if [[ -z "$CF_TOKEN" ]]; then
    echo "ERROR: CF_API_TOKEN not set; export it or store in /root/.credentials/master.env" >&2
    exit 1
  fi
fi

DOMAINS=(of-fund.cz hala-tower.cz patricny-park.cz nebulee.cz)

for d in "${DOMAINS[@]}"; do
  echo "=== $d ==="
  resp=$(curl -s -X POST -H "Authorization: Bearer $CF_TOKEN" -H "Content-Type: application/json" \
    "https://api.cloudflare.com/client/v4/zones" \
    -d "{\"name\":\"$d\",\"account\":{\"id\":\"$ACCOUNT_ID\"},\"type\":\"full\"}")
  ok=$(echo "$resp" | python3 -c 'import sys,json; d=json.load(sys.stdin); print(d.get("success"))')
  if [[ "$ok" == "True" ]]; then
    ns=$(echo "$resp" | python3 -c 'import sys,json; d=json.load(sys.stdin); print("\n".join(d["result"]["name_servers"]))')
    zone_id=$(echo "$resp" | python3 -c 'import sys,json; d=json.load(sys.stdin); print(d["result"]["id"])')
    echo "  ✓ created zone_id=$zone_id"
    echo "$ns" | sed 's/^/    NS: /'
    echo "$d=$zone_id" >> /tmp/sister-zones.txt
  else
    err=$(echo "$resp" | python3 -c 'import sys,json; d=json.load(sys.stdin); print(d.get("errors"))')
    if echo "$err" | grep -q "already exists\|1061"; then
      echo "  · zone already exists — fetching id"
      zone_id=$(curl -s -H "Authorization: Bearer $CF_TOKEN" \
        "https://api.cloudflare.com/client/v4/zones?name=$d" | \
        python3 -c 'import sys,json; r=json.load(sys.stdin)["result"]; print(r[0]["id"] if r else "")')
      echo "    zone_id=$zone_id"
      echo "$d=$zone_id" >> /tmp/sister-zones.txt
    else
      echo "  ✗ ERROR: $err"
    fi
  fi
done

echo ""
echo "=== Next steps ==="
echo "1. Update Wedos NS records for each sister domain (use NS pairs above)."
echo "   Wedos panel: https://client.wedos.com → Doména → Nastavení → DNS servery → Vlastní"
echo "2. Wait ~10–60 min for NS propagation:"
echo "   for d in ${DOMAINS[*]}; do dig +short NS \$d @1.1.1.1; done"
echo "3. Run: ~/Desktop/Codex/ai-control-plane/scripts/cloudflare-publish-sister-dmarc.sh"
echo "4. Verify: ~/Desktop/Codex/ai-control-plane/scripts/verify-finish-list.sh"
