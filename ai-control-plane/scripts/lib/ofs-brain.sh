#!/usr/bin/env bash
# ofs brain — cross-context query
# Hledá v: memory + Obsidian vault + git history + handoffs + recent logs
# Výstup: kompaktní top-N hits per source, anti-halucinace (real grep, ne LLM guess)
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
MEMORY_DIR="$HOME/.claude/projects/-Users-filipdopita-Desktop-Codex/memory"
VAULT_DIR="$HOME/Documents/OneFlow-Vault"
HANDOFFS_DIR="$ROOT/handoffs"
LOG_FILE="$HOME/.claude/logs/ofs.jsonl"

usage() {
  cat <<'EOF'
Usage: ofs brain "query"

Cross-context search across:
  - ~/.claude/projects/.../memory/   (auto-memory)
  - ~/Documents/OneFlow-Vault/        (Obsidian — first 200 most recent)
  - ai-control-plane/handoffs/        (Codex/Claude handoff history)
  - git log --oneline --grep          (commit history of current repo)
  - ofs.jsonl recent (audit trail)

Top-3 hits per source. Compact output.

Příklady:
  ofs brain "outreach Karel"
  ofs brain "DD Patricny"
  ofs brain "Hermes webhook"
EOF
  exit "${1:-1}"
}

[ $# -ge 1 ] || usage
[ "${1:-}" = "--help" ] && usage 0

Q="$*"

color() {
  case "$1" in
    bold)   printf "\033[1m%s\033[0m" "$2" ;;
    blue)   printf "\033[34m%s\033[0m" "$2" ;;
    green)  printf "\033[32m%s\033[0m" "$2" ;;
    yellow) printf "\033[33m%s\033[0m" "$2" ;;
    dim)    printf "\033[2m%s\033[0m" "$2" ;;
    *) printf "%s" "$2" ;;
  esac
}

echo
color bold "ofs brain — query: \"$Q\""; echo
echo "================================================="
echo

# 1. MEMORY
color blue "[memory]"; echo
if [ -d "$MEMORY_DIR" ]; then
  HITS=$(grep -rliE "$Q" "$MEMORY_DIR" 2>/dev/null | head -3)
  if [ -n "$HITS" ]; then
    while IFS= read -r f; do
      [ -z "$f" ] && continue
      bn=$(basename "$f")
      first_match=$(grep -m1 -iE "$Q" "$f" 2>/dev/null | head -c 120)
      echo "  • $bn"
      [ -n "$first_match" ] && echo "    └─ $(color dim "$first_match")"
    done <<< "$HITS"
  else
    color dim "  (no hits)"; echo
  fi
else
  color dim "  (memory dir not found)"; echo
fi
echo

# 2. VAULT (top-3 from 200 most recent)
color blue "[obsidian-vault]"; echo
if [ -d "$VAULT_DIR" ]; then
  # Limit to 200 most recently modified .md files for speed
  HITS=$(find "$VAULT_DIR" -name "*.md" -type f 2>/dev/null \
    | xargs -I{} stat -f '%m %N' {} 2>/dev/null \
    | sort -rn | head -200 | awk '{print $2}' \
    | xargs grep -liE "$Q" 2>/dev/null | head -3)
  if [ -n "$HITS" ]; then
    while IFS= read -r f; do
      [ -z "$f" ] && continue
      rel=${f#$HOME/Documents/OneFlow-Vault/}
      first_match=$(grep -m1 -iE "$Q" "$f" 2>/dev/null | head -c 120)
      echo "  • $rel"
      [ -n "$first_match" ] && echo "    └─ $(color dim "$first_match")"
    done <<< "$HITS"
  else
    color dim "  (no hits in last 200 modified)"; echo
  fi
else
  color dim "  (vault not found)"; echo
fi
echo

# 3. HANDOFFS
color blue "[handoffs]"; echo
if [ -d "$HANDOFFS_DIR" ]; then
  HITS=$(grep -liE "$Q" "$HANDOFFS_DIR"/*.md 2>/dev/null | head -3)
  if [ -n "$HITS" ]; then
    while IFS= read -r f; do
      [ -z "$f" ] && continue
      bn=$(basename "$f")
      first_match=$(grep -m1 -iE "$Q" "$f" 2>/dev/null | head -c 120)
      echo "  • $bn"
      [ -n "$first_match" ] && echo "    └─ $(color dim "$first_match")"
    done <<< "$HITS"
  else
    color dim "  (no hits)"; echo
  fi
fi
echo

# 4. GIT HISTORY (current repo)
color blue "[git-log]"; echo
cd "$ROOT/.." 2>/dev/null && {
  if git rev-parse --git-dir >/dev/null 2>&1; then
    GIT_HITS=$(git log --oneline --grep="$Q" -i 2>/dev/null | head -3)
    if [ -n "$GIT_HITS" ]; then
      printf '%s\n' "$GIT_HITS" | sed 's/^/  • /'
    else
      color dim "  (no commits match)"; echo
    fi
  else
    color dim "  (not a git repo)"; echo
  fi
}
echo

# 5. RECENT OFS LOGS
color blue "[ofs-audit]"; echo
if [ -f "$LOG_FILE" ]; then
  HITS=$(grep -iE "$Q" "$LOG_FILE" 2>/dev/null | tail -3)
  if [ -n "$HITS" ]; then
    while IFS= read -r line; do
      ts=$(printf '%s' "$line" | sed -nE 's/.*"ts":"([^"]+)".*/\1/p')
      action=$(printf '%s' "$line" | sed -nE 's/.*"action":"([^"]+)".*/\1/p')
      detail=$(printf '%s' "$line" | sed -nE 's/.*"detail":"([^"]*)".*/\1/p' | head -c 80)
      echo "  • $ts $action"
      [ -n "$detail" ] && echo "    └─ $(color dim "$detail")"
    done <<< "$HITS"
  else
    color dim "  (no audit hits)"; echo
  fi
fi
echo

echo "================================================="
color dim "Tip: hluboké hledání → grep MEMORY → memory-search MCP → Obsidian /qmd"; echo
