#!/usr/bin/env bash
# ofs gate — pre-deploy / pre-commit quality + security + brand gate
# Combines: secret scan + shell hazards + risky commands + brand + git hygiene + structure.
# Exit code 0 = PASS, 2 = WARN (manual review), 1 = BLOCK
# Note: NO pipefail — grep finding no hits is normal, not error
set -eu

TARGET="${1:-$(pwd)}"

usage() {
  cat <<'EOF'
Usage: ofs gate [PATH]

Runs pre-deploy gate checks against PATH (default: cwd):
  1. SECRET LEAK    — grep API keys / tokens / .env in tracked files
  2. SHELL HAZARDS  — eval, $(curl|bash), rm -rf /, chmod 777
  3. RISKY COMMANDS — destructive/cloud/client-impacting commands for manual review
  4. BRAND VOICE    — banned words v markdown souborech
  5. GIT HYGIENE    — uncommitted, .env tracked, large binary blobs
  6. STRUCTURE      — README/CLAUDE.md exists, executable scripts have shebang

Exit:
  0 PASS   — žádné nálezy nebo jen WARN dimenze
  2 WARN   — manual review doporučen
  1 BLOCK  — kritický problém, NEDEPLOY

Příklady:
  ofs gate                    # current dir
  ofs gate ~/Projects/foo
  cd repo && ofs gate
EOF
  exit "${1:-1}"
}

[ "${1:-}" = "--help" ] && usage 0

if [ ! -d "$TARGET" ]; then
  echo "Path not found: $TARGET" >&2
  exit 1
fi

cd "$TARGET"

color() {
  case "$1" in
    bold)   printf "\033[1m%s\033[0m" "$2" ;;
    red)    printf "\033[31m%s\033[0m" "$2" ;;
    green)  printf "\033[32m%s\033[0m" "$2" ;;
    yellow) printf "\033[33m%s\033[0m" "$2" ;;
    blue)   printf "\033[34m%s\033[0m" "$2" ;;
    dim)    printf "\033[2m%s\033[0m" "$2" ;;
    *) printf "%s" "$2" ;;
  esac
}

CRITICAL=0
WARNINGS=0

echo
color bold "ofs gate — $TARGET"; echo
echo "================================================="

# ─── 1. SECRET LEAK ─────────────────────────────────────
color blue "[1/6] SECRET LEAK"; echo
SECRET_PATTERNS='(sk-ant-[a-zA-Z0-9]{20,}|sk-[a-zA-Z0-9]{40,}|AIza[a-zA-Z0-9_-]{30,}|ghp_[a-zA-Z0-9]{30,}|pit-[a-zA-Z0-9]{15,}|AKIA[0-9A-Z]{16}|xoxb-[0-9]+-[0-9]+-[a-zA-Z0-9]+)'
LEAK_HITS=""
if command -v git >/dev/null && git rev-parse --git-dir >/dev/null 2>&1; then
  # Only check tracked files + untracked (NOT .gitignored)
  CANDIDATES=$( { git ls-files; git ls-files --others --exclude-standard; } 2>/dev/null | head -500)
  if [ -n "$CANDIDATES" ]; then
    LEAK_HITS=$(printf '%s\n' "$CANDIDATES" | xargs grep -lE "$SECRET_PATTERNS" 2>/dev/null | head -10)
  fi
else
  LEAK_HITS=$(grep -rlE "$SECRET_PATTERNS" --exclude-dir=node_modules --exclude-dir=.git --exclude-dir=.venv . 2>/dev/null | head -10)
fi

if [ -n "$LEAK_HITS" ]; then
  color red "  ✗ BLOCK — secrets detected:"; echo
  printf '%s\n' "$LEAK_HITS" | sed 's|^|    |'
  CRITICAL=$((CRITICAL+1))
else
  color green "  ✓ PASS"; echo
fi
echo

# ─── 2. SHELL HAZARDS ───────────────────────────────────
color blue "[2/6] SHELL HAZARDS"; echo
HAZARD_HITS=""
HAZARD_PATTERNS='(curl[^|]*\| ?(bash|sh|zsh)|wget[^|]*\| ?(bash|sh|zsh)|rm -rf /( |$)|chmod 777|eval \$\()'
if command -v git >/dev/null && git rev-parse --git-dir >/dev/null 2>&1; then
  CANDIDATES=$(git ls-files '*.sh' '*.bash' 2>/dev/null | head -200)
  [ -n "$CANDIDATES" ] && HAZARD_HITS=$(printf '%s\n' "$CANDIDATES" | xargs grep -nE "$HAZARD_PATTERNS" 2>/dev/null \
    | grep -vE '(^|/)ofs-gate\.sh:|(^|/)update-extended\.sh:.*NIKDY' \
    | head -5 || true)
else
  HAZARD_HITS=$(find . -name "*.sh" -not -path '*/node_modules/*' -not -path '*/.git/*' 2>/dev/null | head -200 | xargs grep -nE "$HAZARD_PATTERNS" 2>/dev/null \
    | grep -vE '(^|/)ofs-gate\.sh:|(^|/)update-extended\.sh:.*NIKDY' \
    | head -5 || true)
fi

if [ -n "$HAZARD_HITS" ]; then
  color yellow "  ⚠ WARN — shell hazards (review manuálně):"; echo
  printf '%s\n' "$HAZARD_HITS" | sed 's|^|    |' | head -5
  WARNINGS=$((WARNINGS+1))
else
  color green "  ✓ PASS"; echo
fi
echo

# ─── 3. RISKY COMMANDS ───────────────────────────────────
color blue "[3/6] RISKY COMMANDS"; echo
RISKY_HITS=""
RISKY_PATTERNS='(git reset --hard|git clean -fdx|terraform destroy|kubectl delete|gcloud projects delete|aws .* delete-|rm -rf \$[A-Z_]*|chmod -R 777|mkfs\.|dd if=|launchctl unload|security find-(generic|internet)-password)'
if command -v git >/dev/null && git rev-parse --git-dir >/dev/null 2>&1; then
  RISK_FILES=$(git ls-files '*.sh' '*.bash' '*.md' 2>/dev/null | head -500)
  [ -n "$RISK_FILES" ] && RISKY_HITS=$(printf '%s\n' "$RISK_FILES" | xargs grep -nE "$RISKY_PATTERNS" 2>/dev/null \
    | grep -vE '(^|/)ofs-gate\.sh:' \
    | head -10 || true)
else
  RISKY_HITS=$(find . \( -name "*.sh" -o -name "*.md" \) -not -path '*/node_modules/*' -not -path '*/.git/*' 2>/dev/null | head -500 | xargs grep -nE "$RISKY_PATTERNS" 2>/dev/null \
    | grep -vE '(^|/)ofs-gate\.sh:' \
    | head -10 || true)
fi

if [ -n "$RISKY_HITS" ]; then
  color yellow "  ⚠ WARN — high-risk commands or active-scan flags need manual review:"; echo
  printf '%s\n' "$RISKY_HITS" | sed 's|^|    |' | head -10
  WARNINGS=$((WARNINGS+1))
else
  color green "  ✓ PASS"; echo
fi
echo

# ─── 4. BRAND VOICE (banned words v MD) ─────────────────
color blue "[4/6] BRAND VOICE (markdown only)"; echo
BAN_PATTERNS='inovativní|revoluční|komplexní řešení|win-win|synergie|paradigma|disruptivní|dovoluji si|rád bych|s pozdravem|v dnešní době|není žádným tajemstvím|není novinkou|závěrem lze konstatovat|innovative|revolutionary|cutting-edge|game-changing|leverage|paradigm shift|state-of-the-art'
BRAND_HITS=""
if command -v git >/dev/null && git rev-parse --git-dir >/dev/null 2>&1; then
  MD_FILES=$(git ls-files '*.md' 2>/dev/null | head -200)
  [ -n "$MD_FILES" ] && BRAND_HITS=$(printf '%s\n' "$MD_FILES" | xargs grep -inE "$BAN_PATTERNS" 2>/dev/null \
    | grep -vE '^(\.claude-core-rules\.md:.*Žádné|SESSION-|archive/|research-briefings/|scrapling-runs/|ai-control-plane/handoffs/)' \
    | grep -vE '(BANNED_WORDS=|TOOL_INPUT_CONTENT=|opraví .*konkrétní benefit|FAIL detected|detects banned)' \
    | head -10 || true)
else
  BRAND_HITS=$(find . -name "*.md" -not -path '*/node_modules/*' -not -path '*/.git/*' 2>/dev/null | head -200 | xargs grep -inE "$BAN_PATTERNS" 2>/dev/null \
    | grep -vE '^(\.claude-core-rules\.md:.*Žádné|SESSION-|archive/|research-briefings/|scrapling-runs/|ai-control-plane/handoffs/)' \
    | grep -vE '(BANNED_WORDS=|TOOL_INPUT_CONTENT=|opraví .*konkrétní benefit|FAIL detected|detects banned)' \
    | head -10 || true)
fi

if [ -n "$BRAND_HITS" ]; then
  color yellow "  ⚠ WARN — banned words v MD souborech:"; echo
  printf '%s\n' "$BRAND_HITS" | sed 's|^|    |' | head -5
  HIT_COUNT=$(printf '%s\n' "$BRAND_HITS" | wc -l | tr -d ' ')
  [ "$HIT_COUNT" -gt 5 ] && echo "    ... +$((HIT_COUNT-5)) more"
  WARNINGS=$((WARNINGS+1))
else
  color green "  ✓ PASS"; echo
fi
echo

# ─── 5. GIT HYGIENE ──────────────────────────────────────
color blue "[5/6] GIT HYGIENE"; echo
if command -v git >/dev/null && git rev-parse --git-dir >/dev/null 2>&1; then
  ENV_TRACKED=$(git ls-files | grep -E '(^|/)\.env$|(^|/)\.env\.[a-z]+$' | head -5)
  if [ -n "$ENV_TRACKED" ]; then
    color red "  ✗ BLOCK — .env file is tracked:"; echo
    printf '%s\n' "$ENV_TRACKED" | sed 's|^|    |'
    CRITICAL=$((CRITICAL+1))
  fi

  UNCOMMITTED=$(git status --porcelain 2>/dev/null | wc -l | tr -d ' ')
  if [ "$UNCOMMITTED" -gt 0 ]; then
    color yellow "  ⚠ WARN — $UNCOMMITTED uncommitted change(s)"; echo
    WARNINGS=$((WARNINGS+1))
  fi

  LARGE=$(git ls-files | xargs -I{} stat -f '%z %N' {} 2>/dev/null | awk '$1 > 5242880' | head -3)
  if [ -n "$LARGE" ]; then
    color yellow "  ⚠ WARN — large blobs (>5MB) tracked:"; echo
    printf '%s\n' "$LARGE" | sed 's|^|    |'
    WARNINGS=$((WARNINGS+1))
  fi

  [ -z "$ENV_TRACKED" ] && [ "$UNCOMMITTED" -eq 0 ] && [ -z "$LARGE" ] && { color green "  ✓ PASS"; echo; }
else
  color dim "  (not a git repo, skip)"; echo
fi
echo

# ─── 6. STRUCTURE ────────────────────────────────────────
color blue "[6/6] STRUCTURE"; echo
STRUCT_OK=1
[ ! -f README.md ] && [ ! -f README ] && { color yellow "  ⚠ no README"; echo; STRUCT_OK=0; WARNINGS=$((WARNINGS+1)); }
# Check shebangs on .sh in scripts/
NOSHEBANG=$(find . -maxdepth 3 -name "*.sh" -not -path '*/node_modules/*' -not -path '*/.git/*' 2>/dev/null \
  | head -50 \
  | while read -r f; do
      head -1 "$f" 2>/dev/null | grep -qE '^#!' || echo "$f"
    done | head -5)
if [ -n "$NOSHEBANG" ]; then
  color yellow "  ⚠ shell scripts without shebang:"; echo
  printf '%s\n' "$NOSHEBANG" | sed 's|^|    |'
  STRUCT_OK=0
  WARNINGS=$((WARNINGS+1))
fi
[ "$STRUCT_OK" = "1" ] && { color green "  ✓ PASS"; echo; }
echo

# ─── VERDICT ─────────────────────────────────────────────
echo "================================================="
if [ "$CRITICAL" -gt 0 ]; then
  color red "  ✗ BLOCK — $CRITICAL critical issue(s), $WARNINGS warning(s). NEDEPLOY."
  echo
  exit 1
elif [ "$WARNINGS" -gt 0 ]; then
  color yellow "  ⚠ WARN — $WARNINGS warning(s). Manual review doporučen."
  echo
  exit 2
else
  color green "  ✓ PASS — všechny dimenze OK. Ready to ship."
  echo
  exit 0
fi
