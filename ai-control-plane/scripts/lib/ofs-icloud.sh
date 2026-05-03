#!/usr/bin/env bash
# ofs icloud — write/read soubory přes iCloud Drive (transparent sync na Filipův iPhone Files)
#
# Filip má iCloud Drive ON s Desktop + Documents sync. Claude píše do
# ~/Library/Mobile Documents/com~apple~CloudDocs/Claude-Inbox/ → soubor se za pár sekund
# objeví v Files app na iPhonu (záložka iCloud Drive → Claude-Inbox).
#
# Usage:
#   ofs icloud put <local-file>                 # zkopíruj soubor → iCloud Inbox
#   ofs icloud put <file> --as <name>           # rename při kopii
#   ofs icloud note "rychlá poznámka"           # napsat textový note
#   ofs icloud list                              # ls iCloud Inbox
#   ofs icloud open                              # otevřít v Finder
#   ofs icloud rm <file>                        # smaž z Inbox
#
# Author: Dopita, 2026-05-03

set -euo pipefail

ICLOUD_BASE="$HOME/Library/Mobile Documents/com~apple~CloudDocs/Claude-Inbox"
mkdir -p "$ICLOUD_BASE"

cmd="${1:-list}"
shift || true

case "$cmd" in
  put|cp)
    src="${1:-}"
    [ -z "$src" ] && { echo "Usage: ofs icloud put <file> [--as <newname>]"; exit 1; }
    [ -f "$src" ] || { echo "ERR: file not found: $src" >&2; exit 2; }
    dst_name="$(basename "$src")"
    if [ "${2:-}" = "--as" ] && [ -n "${3:-}" ]; then
      dst_name="$3"
    fi
    cp -p "$src" "$ICLOUD_BASE/$dst_name"
    echo "✓ Pushed to iCloud: $dst_name ($(du -h "$src" | cut -f1))"
    echo "   iPhone Files app → iCloud Drive → Claude-Inbox → $dst_name"
    ;;

  note|n)
    msg="$*"
    [ -z "$msg" ] && { echo "Usage: ofs icloud note \"message\""; exit 1; }
    ts="$(date '+%Y%m%d-%H%M%S')"
    fname="note-${ts}.md"
    {
      echo "# Note from Claude (Mac → iPhone)"
      echo
      echo "**Created:** $(date '+%Y-%m-%d %H:%M:%S %Z')"
      echo
      echo "$msg"
    } > "$ICLOUD_BASE/$fname"
    echo "✓ Note written: $fname"
    echo "   iPhone: Files → iCloud Drive → Claude-Inbox → $fname"
    ;;

  list|ls|l)
    echo "iCloud Inbox: $ICLOUD_BASE"
    if [ -z "$(ls -A "$ICLOUD_BASE" 2>/dev/null)" ]; then
      echo "(empty)"
    else
      ls -lhrt "$ICLOUD_BASE" | tail -20
    fi
    ;;

  open|o)
    open "$ICLOUD_BASE"
    ;;

  rm|delete|del)
    fname="${1:-}"
    [ -z "$fname" ] && { echo "Usage: ofs icloud rm <filename>"; exit 1; }
    if [ -f "$ICLOUD_BASE/$fname" ]; then
      rm "$ICLOUD_BASE/$fname"
      echo "✓ Removed: $fname"
    else
      echo "ERR: not found in Inbox: $fname" >&2
      exit 2
    fi
    ;;

  -h|--help|help)
    sed -n '2,16p' "$0" | sed 's/^# \?//'
    ;;

  *)
    echo "Unknown subcommand: $cmd"
    sed -n '2,16p' "$0" | sed 's/^# \?//'
    exit 1
    ;;
esac

# Audit log
ts="$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
printf '{"ts":"%s","action":"icloud","cmd":"%s"}\n' "$ts" "$cmd" \
  >> "$HOME/.claude/logs/ofs.jsonl" 2>/dev/null || true
