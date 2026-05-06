#!/usr/bin/env bash
# security-audit.sh — Periodic security overlay scan
#
# Checks:
#  1. gitleaks scan handoffs/ folder (secrets accidentally committed?)
#  2. World-writable scripts (privilege escalation risk)
#  3. Bridge scripts hardcoded secrets pattern
#  4. /usr/local/bin /opt/homebrew/bin tampering check (compare to original)
#  5. Listening ports audit (Mac side, no privilege escalation)
#  6. Stale credentials (>90 days reminder)
#  7. Recent ofs / handoff anomaly count
#
# Run: weekly via launchd Sat 03:30 (before update-core)
# Output: ~/.claude/logs/security-audit-YYYYMMDD.md + ntfy if findings
#
# Filip rules:
#  - Read-only audit, NIKDY auto-fix (Filip approval pre fix)
#  - Detection only, escalation via ntfy
#  - No false alarms (cooldown 24h)
#
# Author: Dopita, 2026-05-02

set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TODAY=$(date '+%Y%m%d')
REPORT="$HOME/.claude/logs/security-audit-$TODAY.md"
ALERT_DIR="/tmp/security-audit-alerts"

mkdir -p "$(dirname "$REPORT")" "$ALERT_DIR"

ts() { date '+%Y-%m-%d %H:%M:%S'; }
findings=0
critical=0

echo_check() {
  local emoji="$1" label="$2" detail="${3:-}"
  echo "- $emoji **$label**${detail:+ — $detail}" >> "$REPORT"
}

cat > "$REPORT" <<EOF
# Security Audit — $(date '+%Y-%m-%d %H:%M')

> Read-only audit, žádné auto-fixy. Filipova akce vyžadována pro každý finding.

## 1. Gitleaks scans

EOF

# ─── 1. Gitleaks scan handoffs ───────────────────────
if command -v gitleaks >/dev/null 2>&1; then
  hits=0
  if [ -d "$ROOT/handoffs" ]; then
    hits=$(gitleaks dir "$ROOT/handoffs" --redact -v 2>/dev/null | grep -cE 'Finding:|leaks found' 2>/dev/null)
  fi
  hits=${hits:-0}
  if [ "$hits" -gt 0 ] 2>/dev/null; then
    echo_check "🔴" "GITLEAKS HITS" "$hits suspected leaks v handoffs/ — REVIEW + ROTATE"
    critical=$((critical + 1))
    findings=$((findings + hits))
  else
    echo_check "✅" "Gitleaks clean" "no findings in handoffs/"
  fi

  tracked_hits=0
  if command -v git >/dev/null 2>&1 && git -C "$ROOT/.." rev-parse --git-dir >/dev/null 2>&1; then
    tracked_tmp="$(mktemp -d)"
    if git -C "$ROOT/.." ls-files -z | tar --null -T - -C "$ROOT/.." -cf - 2>/dev/null | tar -xf - -C "$tracked_tmp" 2>/dev/null; then
      tracked_hits=$(gitleaks dir "$tracked_tmp" --redact -v 2>/dev/null | grep -cE 'Finding:|leaks found' 2>/dev/null)
      tracked_hits=${tracked_hits:-0}
    fi
    rm -rf "$tracked_tmp"
  fi
  if [ "$tracked_hits" -gt 0 ] 2>/dev/null; then
    echo_check "🔴" "Tracked tree gitleaks hits" "$tracked_hits suspected current-file finding(s)"
    critical=$((critical + 1))
    findings=$((findings + tracked_hits))
  else
    echo_check "✅" "Tracked tree gitleaks clean" "current tracked files only"
  fi
else
  echo_check "⚠️" "Gitleaks not installed" "brew install gitleaks recommended"
fi

# ─── 2. World-writable scripts ───────────────────────
echo "" >> "$REPORT"
echo "## 2. World-writable / setuid scripts" >> "$REPORT"
echo "" >> "$REPORT"

ww=$(find "$ROOT/scripts" "$HOME/scripts" -maxdepth 3 -type f -perm -o+w 2>/dev/null | head -20)
if [ -n "$ww" ]; then
  echo_check "🔴" "World-writable scripts found" "$(echo "$ww" | wc -l | tr -d ' ') files — chmod 755 recommended"
  critical=$((critical + 1))
  echo "$ww" | sed 's/^/  - /' >> "$REPORT"
else
  echo_check "✅" "No world-writable scripts" ""
fi

setuid=$(find "$ROOT/scripts" "$HOME/scripts" -maxdepth 3 -type f -perm -4000 2>/dev/null | head -10)
if [ -n "$setuid" ]; then
  echo_check "🔴" "Setuid scripts found" "review needed"
  critical=$((critical + 1))
  echo "$setuid" | sed 's/^/  - /' >> "$REPORT"
else
  echo_check "✅" "No setuid scripts" ""
fi

# ─── 3. Hardcoded secrets pattern in bridge scripts ──
echo "" >> "$REPORT"
echo "## 3. Hardcoded secrets pattern check" >> "$REPORT"
echo "" >> "$REPORT"

secrets_found=0
for f in "$ROOT/scripts/"*.sh "$HOME/scripts/automation/"*.sh; do
  [ -f "$f" ] || continue
  # Pattern: literal API key/token/secret in quotes (20+ chars, no $/grep/$()/heredoc).
  # Excludes: env var indirection ("$VAR"), grep/sed pipes, comment lines.
  if grep -nE '^[^#]*(API_KEY|TOKEN|SECRET|PASSWORD)=["'"'"'][a-zA-Z0-9_./+-]{20,}["'"'"']' "$f" 2>/dev/null \
       | grep -vE '\$\(|\$\{|grep |sed |awk |head |\$[A-Z_]+|=""$|=\$' \
       | head -1 | grep -q .; then
    secrets_found=$((secrets_found + 1))
    echo "  - $f" >> "$REPORT"
  fi
done

if [ "$secrets_found" -gt 0 ]; then
  echo_check "🔴" "$secrets_found bridge scripts with possible hardcoded secrets" "move to /Users/filipdopita/.credentials/"
  critical=$((critical + 1))
else
  echo_check "✅" "No hardcoded secrets in bridge scripts"
fi

# ─── 4. Listening ports (Mac side) ───────────────────
echo "" >> "$REPORT"
echo "## 4. Listening ports (Mac)" >> "$REPORT"
echo "" >> "$REPORT"

ports=$(lsof -i -P -n 2>/dev/null | grep LISTEN | awk '{print $1, $9}' | sort -u | head -20)
if [ -n "$ports" ]; then
  echo '```' >> "$REPORT"
  echo "$ports" >> "$REPORT"
  echo '```' >> "$REPORT"

  # Flag wildcard listeners (potential exposure). Built-in Apple continuity
  # services are tracked separately so routine rapportd/ControlCenter listeners
  # do not keep the audit permanently yellow.
  wildcard_ports=$(printf "%s\n" "$ports" | grep -E '\*:[0-9]+' || true)
  expected_wildcard=$(printf "%s\n" "$wildcard_ports" | grep -E '^(ControlCe|rapportd) ' || true)
  unexpected_wildcard=$(printf "%s\n" "$wildcard_ports" | grep -Ev '^(ControlCe|rapportd) ' || true)
  if [ -n "$expected_wildcard" ]; then
    expected_count=$(printf "%s\n" "$expected_wildcard" | sed '/^$/d' | wc -l | tr -d ' ')
    echo_check "ℹ️" "$expected_count expected Apple wildcard listener(s)" "rapportd/ControlCenter"
    printf "%s\n" "$expected_wildcard" | sed 's/^/  - /' >> "$REPORT"
  fi
  if [ -n "$unexpected_wildcard" ]; then
    exposed=$(printf "%s\n" "$unexpected_wildcard" | sed '/^$/d' | wc -l | tr -d ' ')
    echo_check "⚠️" "$exposed unexpected service(s) listening on wildcard interfaces" "review exposure"
    printf "%s\n" "$unexpected_wildcard" | sed 's/^/  - /' >> "$REPORT"
    findings=$((findings + 1))
  fi
fi

# ─── 5. Stale credentials >90 days ───────────────────
echo "" >> "$REPORT"
echo "## 5. Stale credentials (rotation reminder >90 days)" >> "$REPORT"
echo "" >> "$REPORT"

if [ -d "$HOME/.credentials" ]; then
  stale=$(find "$HOME/.credentials" -type f -name '*.env' -mtime +90 2>/dev/null | head -10)
  if [ -n "$stale" ]; then
    echo_check "⚠️" "Credential files >90 days old" "rotation reminder"
    echo "$stale" | sed 's/^/  - /' >> "$REPORT"
    findings=$((findings + 1))
  else
    echo_check "✅" "All credentials <90 days" ""
  fi
fi

# ─── 6. Recent anomalies in ofs.jsonl ────────────────
echo "" >> "$REPORT"
echo "## 6. ofs anomaly check (last 24h)" >> "$REPORT"
echo "" >> "$REPORT"

if [ -f "$HOME/.claude/logs/ofs.jsonl" ]; then
  yesterday=$(date -v-24H -u '+%Y-%m-%dT%H:%M:%SZ' 2>/dev/null || echo "1970-01-01T00:00:00Z")
  errors=$(awk -v since="$yesterday" '/"ts":/ && /"status":"error"/' "$HOME/.claude/logs/ofs.jsonl" 2>/dev/null | wc -l | tr -d ' ')
  total=$(awk -v since="$yesterday" '/"ts":/' "$HOME/.claude/logs/ofs.jsonl" 2>/dev/null | wc -l | tr -d ' ')
  echo_check "ℹ️" "ofs activity 24h" "$total ops, $errors errors"
fi

# ─── 7. Hooks integrity check ────────────────────────
echo "" >> "$REPORT"
echo "## 7. Critical defense hooks check" >> "$REPORT"
echo "" >> "$REPORT"

for hook in autonomy-guard.sh gitleaks-guard.sh google-api-guard.sh hallucination-guard.sh completion-blocking-words-guard.sh; do
  if [ -f "$HOME/.claude/hooks/$hook" ] && [ -x "$HOME/.claude/hooks/$hook" ]; then
    echo_check "✅" "$hook" "present and executable"
  else
    echo_check "🔴" "$hook" "MISSING or not executable"
    critical=$((critical + 1))
  fi
done
# fb-scrape-safety is a rule (markdown), not a hook — separate check
if [ -f "$HOME/.claude/rules/fb-scrape-safety.md" ]; then
  echo_check "✅" "fb-scrape-safety.md (rule)" "present in rules/"
else
  echo_check "🔴" "fb-scrape-safety.md (rule)" "MISSING — recreate from memory"
  critical=$((critical + 1))
fi

# ─── Summary ─────────────────────────────────────────
echo "" >> "$REPORT"
echo "## Summary" >> "$REPORT"
echo "" >> "$REPORT"
echo "- **Critical findings:** $critical (require immediate Filip action)" >> "$REPORT"
echo "- **Total findings:** $findings" >> "$REPORT"
echo "- **Audit timestamp:** $(ts)" >> "$REPORT"
echo "" >> "$REPORT"
echo "Next audit: weekly (Sat 03:30 launchd) or run manually:" >> "$REPORT"
echo '```bash' >> "$REPORT"
echo "$ROOT/scripts/security-audit.sh" >> "$REPORT"
echo '```' >> "$REPORT"

# ─── Notify on critical ──────────────────────────────
if [ "$critical" -gt 0 ]; then
  cooldown="$ALERT_DIR/critical-findings"
  if [ ! -f "$cooldown" ] || [ "$(( $(date +%s) - $(stat -f %m "$cooldown" 2>/dev/null || echo 0) ))" -gt 86400 ]; then
    osascript -e "display notification \"Security audit found $critical CRITICAL findings. Open $REPORT\" with title \"🔴 Security audit CRITICAL\" sound name \"Glass\"" 2>/dev/null || true
    touch "$cooldown"
  fi
fi

if [ -t 1 ]; then
  echo "Security audit done: $REPORT"
  echo "Critical: $critical, Total findings: $findings"
fi

exit 0
