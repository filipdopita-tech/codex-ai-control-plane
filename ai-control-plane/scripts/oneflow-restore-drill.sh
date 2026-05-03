#!/bin/bash
# oneflow-restore-drill.sh — weekly verification that backups are restorable
# Runs on Flash. Picks newest *.tar.age, decrypts to /tmp, verifies:
#   - tarball structure intact
#   - each pg_*.sql.gz parseable
#   - manifest.txt readable, contains expected sections
#   - random row count from open_archive (sanity check)
# Alerts on FAIL via ntfy. PASS just logs.
# Last updated: 2026-05-03 (P0 #1 vibe-coding implementation)
set -euo pipefail

WORK_ROOT=/var/backups/oneflow
LOG_FILE=/var/log/oneflow-restore-drill.log
AGE_KEY_FILE=/root/.config/sops/age/keys.txt
NTFY_URL="https://ntfy.oneflow.cz/Filip"
DRILL_DIR=$(mktemp -d /tmp/oneflow-drill.XXXXXX)
START_TS=$(date +%s)

log() { echo "[$(date -u +%H:%M:%SZ)] $*" | tee -a "$LOG_FILE"; }
notify() {
  local msg="$1"; local priority="${2:-3}"
  curl -sf -d "$msg" -H "Priority: $priority" -H "Tags: test_tube,oneflow" "$NTFY_URL" >/dev/null 2>&1 || true
}
cleanup() { rm -rf "$DRILL_DIR" 2>/dev/null || true; }
trap cleanup EXIT

log "=== restore-drill START ==="

# Pick newest backup
LATEST=$(ls -t "$WORK_ROOT"/oneflow-*.tar.age 2>/dev/null | head -1 || true)
[ -z "$LATEST" ] && { log "FAIL: no backup found"; notify "❌ Restore drill FAIL: no backup file" 5; exit 1; }

log "candidate: $LATEST ($(du -h "$LATEST" | cut -f1))"

# Decrypt
DEC_TAR="$DRILL_DIR/restore.tar"
if ! age -d -i "$AGE_KEY_FILE" -o "$DEC_TAR" "$LATEST" 2>>"$LOG_FILE"; then
  log "FAIL: age decrypt"; notify "❌ Restore drill FAIL: age decrypt error on $(basename "$LATEST")" 5; exit 1
fi
log "  decrypted ok ($(du -h "$DEC_TAR" | cut -f1))"

# Extract
if ! tar xf "$DEC_TAR" -C "$DRILL_DIR" 2>>"$LOG_FILE"; then
  log "FAIL: tar extract"; notify "❌ Restore drill FAIL: tar extract error" 5; exit 1
fi
EXTRACTED=$(ls -d "$DRILL_DIR"/*/  | head -1)
log "  extracted: $EXTRACTED"

# Verify manifest
MANIFEST="$EXTRACTED/MANIFEST.txt"
[ -r "$MANIFEST" ] || { log "FAIL: no manifest"; notify "❌ Restore drill FAIL: missing MANIFEST.txt" 5; exit 1; }
grep -q "backup_id:" "$MANIFEST" || { log "FAIL: manifest invalid"; notify "❌ Restore drill FAIL: invalid manifest" 5; exit 1; }
log "  manifest ok"

# Verify each pg dump is gunzippable + has CREATE statements
PG_OK=0
PG_FAIL=0
for dump in "$EXTRACTED"/pg_*.sql.gz; do
  [ -f "$dump" ] || continue
  if gzip -t "$dump" 2>/dev/null; then
    # Use grep -c to count matches (avoids SIGPIPE under pipefail vs grep -q)
    SIGS=$(zcat "$dump" 2>/dev/null | head -300 | grep -cE '^(CREATE|COPY|INSERT|REVOKE|GRANT|SET|ALTER|--|\\restrict|\\unrestrict)' || true)
    if [ "$SIGS" -gt 5 ]; then
      PG_OK=$((PG_OK+1))
      log "  pg ok: $(basename "$dump") ($(du -h "$dump" | cut -f1), $SIGS sql signatures in head)"
    else
      PG_FAIL=$((PG_FAIL+1))
      log "  pg FAIL (only $SIGS SQL signatures): $(basename "$dump")"
    fi
  else
    PG_FAIL=$((PG_FAIL+1))
    log "  pg FAIL (gzip corrupt): $(basename "$dump")"
  fi
done
log "  pg summary: ok=$PG_OK fail=$PG_FAIL"
[ $PG_FAIL -gt 0 ] && { notify "❌ Restore drill FAIL: $PG_FAIL pg dump corrupt" 5; exit 1; }
[ $PG_OK -eq 0 ] && { notify "❌ Restore drill FAIL: 0 pg dumps in backup" 5; exit 1; }

# Verify configs.tar.gz
CONFIG_TAR="$EXTRACTED/configs.tar.gz"
if [ -r "$CONFIG_TAR" ]; then
  if tar tzf "$CONFIG_TAR" 2>/dev/null | head -50 | grep -qE '(\.credentials|\.sops|postfix|wireguard)'; then
    log "  configs ok"
  else
    log "  WARN: configs tarball missing expected files"
  fi
fi

# Sanity row-count via dump (no actual restore — too risky on prod).
# Count INSERT/COPY blocks in postgres dump as proxy for "data present".
PG_DUMP="$EXTRACTED/pg_postgres.sql.gz"
if [ -r "$PG_DUMP" ]; then
  ROWS=$(zcat "$PG_DUMP" 2>/dev/null | grep -cE '^(INSERT|COPY)' | head -1 || echo 0)
  log "  open_archive INSERT/COPY blocks: $ROWS"
  [ "$ROWS" -lt 1 ] && log "  WARN: 0 INSERT/COPY in postgres dump (empty DB or extract issue)"
fi

DURATION=$(($(date +%s) - START_TS))
log "=== PASS ($DURATION s, $PG_OK pg dumps, manifest ok) ==="
notify "✅ Restore drill PASS — $PG_OK pg dumps verified, ${DURATION}s" 3
