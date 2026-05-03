#!/usr/bin/env bash
# sync-ecosystem-to-flash — mirror Mac ~/.claude/{rules,knowledge,expertise,skills,agents,commands,CLAUDE.md}
# do Flash /root/.claude-ecosystem/. Tím Flash claude-rc session má rámku LOCAL,
# nezávisle na SSHFS Mac→/mac mountu (přežije Mac sleep, network drop, Mac restart).
#
# Vyloučeno: memory/, projects/, creds-backup/, .credentials, hooks/ (Mac paths),
#            cache/, node_modules/, __pycache__, .git/, *.pyc, .DS_Store, audity, backups.
#
# Usage:
#   sync-ecosystem-to-flash.sh                # full sync
#   sync-ecosystem-to-flash.sh --dry-run      # preview
#   sync-ecosystem-to-flash.sh --force        # overwrite even pokud Flash novější
#
# Wrapped via: ofs mobile-flash sync-ecosystem
#
# Author: Dopita, 2026-05-03

set -euo pipefail

VPS="root@10.77.0.1"
SRC="$HOME/.claude"
DST="/root/.claude-ecosystem"
LOG="$HOME/.claude/logs/sync-ecosystem.log"
mkdir -p "$(dirname "$LOG")"

DRY=0
FORCE=0
for a in "$@"; do
  case "$a" in
    --dry-run|-n) DRY=1 ;;
    --force|-f)   FORCE=1 ;;
    -h|--help)    sed -n '2,17p' "$0" | sed 's/^# \?//'; exit 0 ;;
  esac
done

say()  { printf "\033[1;34m▶\033[0m %s\n" "$*"; }
ok()   { printf "\033[1;32m✓\033[0m %s\n" "$*"; }
warn() { printf "\033[1;33m!\033[0m %s\n" "$*"; }
err()  { printf "\033[1;31m✗\033[0m %s\n" "$*" >&2; }

# Pre-flight
ssh -o ConnectTimeout=5 -o BatchMode=yes "$VPS" true 2>/dev/null \
  || { err "VPS Flash unreachable ($VPS). Check WG."; exit 2; }
ok "VPS reachable"

# Ensure target dir + permissions
ssh "$VPS" "mkdir -p $DST && chmod 700 $DST"

# Build rsync flags
RSYNC_FLAGS=(-avh --delete --human-readable)
[ "$DRY" -eq 1 ] && RSYNC_FLAGS+=(--dry-run)
[ "$FORCE" -eq 0 ] && RSYNC_FLAGS+=(--update)  # skip if Flash file is newer

# Universal excludes (apply to every source dir)
EXCLUDES=(
  --exclude='.git/'
  --exclude='.DS_Store'
  --exclude='node_modules/'
  --exclude='__pycache__/'
  --exclude='*.pyc'
  --exclude='*.pyo'
  --exclude='.venv/'
  --exclude='venv/'
  --exclude='.cache/'
  --exclude='cache/'
  --exclude='*.log'
  --exclude='*.pid'
  --exclude='.pytest_cache/'
  --exclude='dist/'
  --exclude='build/'
  --exclude='target/'
)

say "Sync 1/7 — CLAUDE.md (root config)"
rsync "${RSYNC_FLAGS[@]}" "${EXCLUDES[@]}" "$SRC/CLAUDE.md" "$VPS:$DST/" \
  || warn "CLAUDE.md sync issue"

say "Sync 2/7 — rules/ (behavioral hard rules)"
rsync "${RSYNC_FLAGS[@]}" "${EXCLUDES[@]}" "$SRC/rules/" "$VPS:$DST/rules/"

say "Sync 3/7 — knowledge/ (lazy-load rules + curated)"
rsync "${RSYNC_FLAGS[@]}" "${EXCLUDES[@]}" "$SRC/knowledge/" "$VPS:$DST/knowledge/"

say "Sync 4/7 — expertise/ (YAML domain configs)"
rsync "${RSYNC_FLAGS[@]}" "${EXCLUDES[@]}" "$SRC/expertise/" "$VPS:$DST/expertise/"

say "Sync 5/7 — skills/ (336 skills, ~1.1GB; with extra excludes for runtime artifacts)"
rsync "${RSYNC_FLAGS[@]}" "${EXCLUDES[@]}" \
  --exclude='*/screenshots/' \
  --exclude='*/output/' \
  --exclude='*/outputs/' \
  --exclude='*/results/' \
  --exclude='*/runs/' \
  --exclude='*/.tmp/' \
  --exclude='*/tmp/' \
  --exclude='*/models/' \
  --exclude='*/checkpoints/' \
  --exclude='*/embeddings/' \
  --exclude='*/data/cache/' \
  "$SRC/skills/" "$VPS:$DST/skills/"

say "Sync 6/7 — agents/ (55 subagent definitions)"
rsync "${RSYNC_FLAGS[@]}" "${EXCLUDES[@]}" "$SRC/agents/" "$VPS:$DST/agents/"

say "Sync 7/7 — commands/ (191 slash command definitions)"
if [ -d "$SRC/commands" ]; then
  rsync "${RSYNC_FLAGS[@]}" "${EXCLUDES[@]}" "$SRC/commands/" "$VPS:$DST/commands/"
else
  warn "No commands/ dir on Mac, skipping"
fi

# Generate manifest with timestamps
ssh "$VPS" "
  cd $DST
  {
    echo '# Ecosystem manifest (synced from Mac \$HOME/.claude/)'
    echo \"# Last sync: \$(date -u '+%Y-%m-%dT%H:%M:%SZ')\"
    echo \"# Source host: \$(hostname)\"
    echo ''
    echo '## File counts'
    for d in rules knowledge expertise skills agents commands; do
      [ -d \"\$d\" ] && printf '  %-12s %5d files (%s)\n' \"\$d\" \"\$(find \$d -type f | wc -l)\" \"\$(du -sh \$d | cut -f1)\"
    done
    echo ''
    echo '## Total size'
    du -sh $DST | cut -f1
  } > $DST/MANIFEST.md
  chmod 644 $DST/MANIFEST.md
"

ok "Manifest generated: $DST/MANIFEST.md"

# Verify final state
say "Verify"
SIZE_TOTAL="$(ssh "$VPS" "du -sh $DST 2>/dev/null | cut -f1")"
COUNT_TOTAL="$(ssh "$VPS" "find $DST -type f 2>/dev/null | wc -l")"
ok "Total: $SIZE_TOTAL across $COUNT_TOTAL files"

ssh "$VPS" "cat $DST/MANIFEST.md" | sed 's/^/  /'

# Audit log
ts="$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
printf '{"ts":"%s","action":"sync-ecosystem","status":"ok","size":"%s","files":%s,"dry_run":%s}\n' \
  "$ts" "$SIZE_TOTAL" "$COUNT_TOTAL" "$DRY" >> "$LOG"

cat <<EOF

╭─────────────────────────────────────────────────────────────────╮
│  HOTOVO — Ekosystém synced to Flash                             │
├─────────────────────────────────────────────────────────────────┤
│  Flash dir:    $DST
│  Total:        $SIZE_TOTAL ($COUNT_TOTAL files)
│  Manifest:     $DST/MANIFEST.md
│                                                                 │
│  Service unit env (po deploy):                                  │
│    CLAUDE_CODE_ADDITIONAL_DIRECTORIES_CLAUDE_MD=$DST
│                                                                 │
│  Re-sync kdykoli:                                               │
│    ofs mobile-flash sync-ecosystem                              │
│                                                                 │
│  Auto-sync cron:  /etc/cron.d/claude-ecosystem-sync (00:30 UTC) │
╰─────────────────────────────────────────────────────────────────╯

EOF
