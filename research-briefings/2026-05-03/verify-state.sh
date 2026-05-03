#!/bin/bash
# verify-state.sh — checks Alex2Learn Phase 6 closure state
# Run při startu next session pro fresh state map.

echo "=== 1. Phase 6 LIVE artifacts ==="
test -f ~/.credentials/instagram_meta.env && echo "✓ instagram_meta.env"
curl -sI https://filipdopita-tech.github.io/oneflow-legal/instagram-privacy.html 2>&1 | head -1
curl -sI https://filipdopita-tech.github.io/oneflow-legal/instagram-terms.html 2>&1 | head -1
test -d ~/Desktop/llm-council && echo "✓ Karpathy llm-council"

echo ""
echo "=== 2. ig_api.py smoke test ==="
bash -c 'set -a; source ~/.credentials/instagram_meta.env 2>/dev/null; set +a
python3 ~/.claude/skills/instagram-meta-api/scripts/ig_api.py get_profile 2>&1 | grep -E "username|followers_count|media_count"'

echo ""
echo "=== 3. Single remaining gate state ==="
echo "Sister DMARC:"
for d in of-fund.cz hala-tower.cz patricny-park.cz nebulee.cz; do
  printf "  %-22s " "$d"
  result=$(dig +short TXT _dmarc.$d 2>/dev/null | head -1 | grep -oE 'p=[a-z]+')
  echo "${result:-MISSING}"
done
echo "DNSSEC DS oneflow.cz:"
ds=$(dig +short DS oneflow.cz @8.8.8.8 2>/dev/null | head -1)
echo "  ${ds:-MISSING}"

echo ""
echo "=== 4. Wedos finisher state (Flash side) ==="
ssh -o ConnectTimeout=8 root@10.77.0.1 'tail -5 /var/log/wedos-auto-finisher.log 2>/dev/null || echo "(no log yet — WAPI not yet enabled or never run)"'

echo ""
echo "=== 5. Cloudflare zone state ==="
ssh -o ConnectTimeout=8 root@10.77.0.1 'source /root/.credentials/master.env 2>/dev/null
for d in of-fund.cz hala-tower.cz patricny-park.cz nebulee.cz oneflow.cz; do
  printf "  %-22s " "$d"
  curl -sH "Authorization: Bearer $CF_API_TOKEN" "https://api.cloudflare.com/client/v4/zones?name=$d" 2>/dev/null | python3 -c "import sys,json
try:
    r=json.load(sys.stdin).get(\"result\",[])
    print(r[0][\"status\"] if r else \"NOT_IN_CF\")
except: print(\"ERR\")"
done'

echo ""
echo "=== 6. Latest closure commits (last 2 days) ==="
cd ~/Desktop/Codex && git log --oneline --since="2 days ago" 2>/dev/null | grep -iE "alex2learn|wedos|sister|cloudflare|finish|closure|phase" | head -8

echo ""
echo "=== Decision ==="
echo "  Pokud sister DMARC + DS = present  → PATH succeeded, write Phase 7 closure"
echo "  Pokud both MISSING + Wedos log empty + CF zones NOT_IN_CF → Filip didn't trigger PATH yet"
echo "  Pokud Wedos log shows WAPI 2051 → Filip didn't enable yet"
echo "  Pokud CF zones present but DMARC missing → run cloudflare-publish-sister-dmarc.sh"
