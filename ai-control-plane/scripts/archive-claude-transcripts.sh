#!/usr/bin/env bash
set -euo pipefail

CLAUDE_DIR="${CLAUDE_DIR:-$HOME/.claude}"
PROJECTS_DIR="$CLAUDE_DIR/projects"
ARCHIVE_ROOT="$CLAUDE_DIR/projects-archive"
DAYS=14
APPLY=0
LIST=0

usage() {
  cat <<'USAGE'
Usage: archive-claude-transcripts.sh [--days N] [--apply] [--list]

Moves old Claude Code project transcript JSONL files out of the active
~/.claude/projects resume index and into ~/.claude/projects-archive.

Default is dry-run. Use --apply to move files. Nothing is deleted.
Use --list to show existing archive batches.
USAGE
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --days)
      DAYS="${2:-}"
      shift 2
      ;;
    --apply)
      APPLY=1
      shift
      ;;
    --list)
      LIST=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "ERROR: unknown argument: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

if [ "$LIST" -eq 1 ]; then
  if [ ! -d "$ARCHIVE_ROOT" ]; then
    echo "No transcript archives at $ARCHIVE_ROOT"
    exit 0
  fi
  find "$ARCHIVE_ROOT" -maxdepth 2 -name MANIFEST.tsv -print | sort | while IFS= read -r manifest; do
    archive_dir="$(dirname "$manifest")"
    count="$(($(wc -l < "$manifest" | tr -d ' ') - 1))"
    size="$(du -sh "$archive_dir" 2>/dev/null | awk '{print $1}')"
    printf "%-8s %5s files  %s\n" "$size" "$count" "$archive_dir"
  done
  exit 0
fi

case "$DAYS" in
  ''|*[!0-9]*)
    echo "ERROR: --days must be a positive integer" >&2
    exit 2
    ;;
esac

if [ "$DAYS" -lt 7 ]; then
  echo "ERROR: refusing to archive transcripts newer than 7 days" >&2
  exit 2
fi

if [ ! -d "$PROJECTS_DIR" ]; then
  echo "No Claude projects directory at $PROJECTS_DIR"
  exit 0
fi

stamp="$(date +%Y%m%d-%H%M%S)"
archive_dir="$ARCHIVE_ROOT/$stamp"
manifest="$archive_dir/MANIFEST.tsv"

count=0
bytes=0

while IFS= read -r -d '' file; do
  count=$((count + 1))
  size="$(stat -f '%z' "$file" 2>/dev/null || echo 0)"
  bytes=$((bytes + size))
done < <(find "$PROJECTS_DIR" -type f -name '*.jsonl' -mtime +"$DAYS" -print0)

mb=$((bytes / 1024 / 1024))

if [ "$APPLY" -eq 0 ]; then
  echo "DRY RUN: would archive $count transcript(s), about ${mb}MB, older than $DAYS days."
  echo "Archive target: $archive_dir"
  echo
  find "$PROJECTS_DIR" -type f -name '*.jsonl' -mtime +"$DAYS" -exec ls -lh {} + 2>/dev/null \
    | sort -k5 -hr \
    | sed -n '1,20p'
  exit 0
fi

mkdir -p "$archive_dir"
printf "source\tsize_bytes\tarchived_to\n" > "$manifest"

while IFS= read -r -d '' file; do
  rel="${file#"$PROJECTS_DIR"/}"
  dest="$archive_dir/projects/$rel"
  mkdir -p "$(dirname "$dest")"
  size="$(stat -f '%z' "$file" 2>/dev/null || echo 0)"
  mv "$file" "$dest"
  printf "%s\t%s\t%s\n" "$file" "$size" "$dest" >> "$manifest"
done < <(find "$PROJECTS_DIR" -type f -name '*.jsonl' -mtime +"$DAYS" -print0)

echo "Archived $count transcript(s), about ${mb}MB, older than $DAYS days."
echo "Archive: $archive_dir"
echo "Manifest: $manifest"
