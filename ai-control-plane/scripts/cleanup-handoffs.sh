#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: cleanup-handoffs.sh [--days N] [--keep N] [--dry-run]

Rotates ai-control-plane/handoffs/ to keep audit trail bounded.

Options:
  --days N    delete handoffs older than N days (default 30)
  --keep N    always keep newest N regardless of age (default 50)
  --dry-run   list what would be deleted, don't delete
  --help      show this message

Exit codes:
  0  ok
  1  bad usage
EOF
  exit "${1:-1}"
}

DAYS=30
KEEP=50
DRY_RUN=0

while [ $# -gt 0 ]; do
  case "$1" in
    --days) DAYS="$2"; shift 2 ;;
    --keep) KEEP="$2"; shift 2 ;;
    --dry-run) DRY_RUN=1; shift ;;
    --help|-h) usage 0 ;;
    *) echo "Unknown arg: $1" >&2; usage 1 ;;
  esac
done

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HANDOFF_DIR="$ROOT/handoffs"

if [ ! -d "$HANDOFF_DIR" ]; then
  echo "No handoffs directory: $HANDOFF_DIR"
  exit 0
fi

mapfile -t ALL_FILES < <(ls -1t "$HANDOFF_DIR" 2>/dev/null | grep -E '\.md$' || true)
TOTAL=${#ALL_FILES[@]}

if [ "$TOTAL" -le "$KEEP" ]; then
  echo "Total $TOTAL handoffs <= keep threshold $KEEP. Nothing to rotate."
  exit 0
fi

CANDIDATES=("${ALL_FILES[@]:$KEEP}")
NOW="$(date +%s)"
CUTOFF=$((NOW - DAYS * 86400))

DELETED=0
for f in "${CANDIDATES[@]}"; do
  full="$HANDOFF_DIR/$f"
  mtime="$(stat -f %m "$full" 2>/dev/null || stat -c %Y "$full" 2>/dev/null || echo 0)"
  if [ "$mtime" -lt "$CUTOFF" ]; then
    if [ "$DRY_RUN" = "1" ]; then
      echo "WOULD DELETE: $f"
    else
      rm -f "$full"
      echo "deleted: $f"
    fi
    DELETED=$((DELETED + 1))
  fi
done

echo
echo "Total handoffs: $TOTAL"
echo "Kept (newest): $KEEP"
echo "Eligible (older than $DAYS days, beyond keep): $DELETED"
[ "$DRY_RUN" = "1" ] && echo "(dry-run; nothing actually deleted)"
