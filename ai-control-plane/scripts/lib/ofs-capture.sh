#!/usr/bin/env bash
# ofs capture — quick capture nápadu/poznámky do Obsidian vault + log
# Brand-aware: čas + project context + tags
set -euo pipefail

VAULT_DIR="$HOME/Documents/OneFlow-Vault"
INBOX_DIR="$VAULT_DIR/01-Inbox"
CAPTURE_LOG="$HOME/.claude/logs/captures.jsonl"
mkdir -p "$INBOX_DIR" "$(dirname "$CAPTURE_LOG")"

usage() {
  cat <<'EOF'
Usage: ofs capture "text nápadu / poznámky"
       ofs capture --tag idea "text"
       ofs capture --tag todo "text"
       ofs capture --tag insight "text"

Quick capture do Obsidian vault inbox (~/Documents/OneFlow-Vault/01-Inbox/).
Tag: idea | todo | insight | meeting | followup (default: idea)

Příklady:
  ofs capture "weekly newsletter automation idea"
  ofs capture --tag todo "follow up s Karlem 2026-05-08"
  ofs capture --tag insight "investor meeting: chce 10% IRR floor"
EOF
  exit "${1:-1}"
}

[ $# -ge 1 ] || usage
[ "${1:-}" = "--help" ] && usage 0

TAG="idea"
if [ "${1:-}" = "--tag" ]; then
  TAG="${2:-idea}"
  shift 2
fi

[ $# -ge 1 ] || usage
TEXT="$*"

ts() { date -u '+%Y-%m-%dT%H:%M:%SZ'; }
NOW_LOCAL=$(date '+%Y-%m-%d %H:%M')
NOW_FILE=$(date '+%Y%m%d-%H%M%S')

# Detect project context (first 60 chars of cwd)
CWD_HINT="$(pwd | sed "s|^$HOME|~|")"
PROJECT_HINT=$(basename "$(pwd)")

# Build filename — first 40 chars of text, slug-ified
# (iconv with //TRANSLIT exits 1 on invalid chars even when output is fine — wrap in || true)
set +o pipefail
SLUG=$(printf '%s' "$TEXT" | head -c 40 | { iconv -f UTF-8 -t ASCII//TRANSLIT 2>/dev/null || cat; } | tr -cs 'a-zA-Z0-9' '-' | sed 's/^-//;s/-$//' | tr '[:upper:]' '[:lower:]')
set -o pipefail
[ -z "$SLUG" ] && SLUG="capture"
FILE="$INBOX_DIR/${NOW_FILE}-${TAG}-${SLUG}.md"

# Write capture
cat > "$FILE" <<EOF
---
created: $NOW_LOCAL
tag: $TAG
project: $PROJECT_HINT
cwd: $CWD_HINT
captured_via: ofs capture
---

# $TEXT

**Captured:** $NOW_LOCAL
**Project context:** \`$CWD_HINT\`
**Tag:** #$TAG

## Notes



## Action

- [ ] (define next action)

EOF

# Log
printf '{"ts":"%s","tag":"%s","file":"%s","text":"%s","project":"%s"}\n' \
  "$(ts)" "$TAG" "$FILE" \
  "$(printf '%s' "$TEXT" | head -c 200 | sed 's/"/\\"/g')" \
  "$PROJECT_HINT" \
  >> "$CAPTURE_LOG"

color() {
  case "$1" in
    bold) printf "\033[1m%s\033[0m" "$2" ;;
    green) printf "\033[32m%s\033[0m" "$2" ;;
    dim) printf "\033[2m%s\033[0m" "$2" ;;
    *) printf "%s" "$2" ;;
  esac
}

color green "✓ captured"; echo
echo "  file: $FILE"
echo "  tag:  #$TAG"
echo "  project: $PROJECT_HINT"
color dim "  → review later in: 01-Inbox/"; echo
