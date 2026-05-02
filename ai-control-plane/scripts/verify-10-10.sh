#!/usr/bin/env bash
# 16/16 verification — runs without destructive deletion
echo "=== EKOSYSTEM 10/10 MAX VERIFICATION ==="
echo

PASS=0
FAIL=0

check() {
  local n="$1" desc="$2" cmd="$3"
  if eval "$cmd" >/dev/null 2>&1; then
    echo "  ✓ $n. $desc"
    PASS=$((PASS+1))
  else
    echo "  ✗ $n. $desc"
    FAIL=$((FAIL+1))
  fi
}

# Base layer (Wave 0–2)
check 1 "ofs CLI installed" "[ -x \$HOME/.local/bin/ofs ]"
check 2 "ofs status works" "\$HOME/.local/bin/ofs status"
check 3 "VPS Flash reachable" "ssh -o ConnectTimeout=5 root@10.77.0.1 'true'"
check 4 "Hermes systemd unit exists" "ssh root@10.77.0.1 'systemctl --user list-unit-files hermes-gateway.service' | grep -q hermes"
check 5 "dispatch.oneflow.cz HTTPS 401 reject" "curl -s -o /dev/null -w '%{http_code}' --max-time 10 -X POST https://dispatch.oneflow.cz/webhooks/dispatch -d '{}' | grep -q 401"
check 6 "launchd 6+ agents loaded" "[ \$(launchctl list 2>/dev/null | grep -c filipdopita) -ge 6 ]"
check 7 "Obsidian dashboard symlink exists" "[ -f \$HOME/.claude/logs/ecosystem-status.md ]"

# Power layer (Wave 3)
check 8 "ofs do (smart router→capture)" "\$HOME/.local/bin/ofs do 'uložit nápad: verify' | grep -q captured"
check 9 "ofs gate (5 dim check, exit 0|2)" "\$HOME/.local/bin/ofs gate ai-control-plane; [ \$? -le 2 ]"
check 10 "ofs heal --dry-run runs" "\$HOME/.local/bin/ofs heal --dry-run --no-notify; [ \$? -le 2 ]"
check 11 "ofs metrics --json valid" "\$HOME/.local/bin/ofs metrics --json | grep -q '\"window_days\"'"
check 12 "ofs brand detects banned words" "echo 'Dovoluji si win-win' | \$HOME/.local/bin/ofs brand - | grep -q FAIL"
check 13 "ofs eval scores text" "echo 'test eval text content here' > /tmp/_eval_v.md; \$HOME/.local/bin/ofs eval --type generic /tmp/_eval_v.md | grep -q COMPOSITE"
check 14 "ofs swap diagnostics" "\$HOME/.local/bin/ofs swap --threshold 99 | grep -q 'Swap usage'"
check 15 "ofs brain cross-search" "\$HOME/.local/bin/ofs brain 'ofs' | grep -q memory"
check 16 "ofs capture vault inbox" "\$HOME/.local/bin/ofs capture --tag idea verify-\$(date +%s) | grep -q captured"

echo
TOTAL=$((PASS + FAIL))
echo "═══ $PASS/$TOTAL PASS ═══"
[ "$FAIL" -eq 0 ] && echo "✓ 10/10 MAX — ekosystem complete" || echo "⚠ $FAIL fails — review"
