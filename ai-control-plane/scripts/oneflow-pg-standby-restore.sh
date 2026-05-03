#!/bin/bash
# oneflow-pg-standby-restore.sh — load latest backup PG dumps into a standby cluster on Mac
# Runs on Mac. Pulls newest /mac/Documents/oneflow-backups/oneflow-*.tar.age,
# decrypts, extracts pg_*.sql.gz, restores into a local Docker postgres container.
# Result: cold-restore standby ready to promote within minutes (RTO ~5min after script run).
#
# Pre-req: docker, age installed on Mac, age key at ~/.config/sops/age/keys.txt.
# Promote runbook: see /Users/filipdopita/Desktop/Codex/ai-control-plane/docs/dr-failover.md
set -euo pipefail

BACKUP_DIR="${BACKUP_DIR:-${HOME}/Documents/oneflow-backups}"
WORK_DIR=$(mktemp -d /tmp/pg-standby.XXXXXX)
AGE_KEY_FILE="${AGE_KEY_FILE:-${HOME}/.config/sops/age/keys.txt}"
STANDBY_DATA="${STANDBY_DATA:-${HOME}/Library/oneflow-pg-standby}"
STANDBY_CONTAINER="${STANDBY_CONTAINER:-oneflow-pg-standby}"
PG_VERSION="${PG_VERSION:-15}"
PG_PORT="${PG_PORT:-15432}"   # non-default to avoid conflict with anything Mac runs

cleanup() { rm -rf "$WORK_DIR" 2>/dev/null || true; }
trap cleanup EXIT

log() { echo "[$(date -u +%H:%M:%SZ)] $*"; }

log "=== PG warm-standby restore start ==="
[ -d "$BACKUP_DIR" ] || { echo "ERR: $BACKUP_DIR not found"; exit 1; }

LATEST=$(ls -t "$BACKUP_DIR"/oneflow-*.tar.age 2>/dev/null | head -1 || true)
[ -z "$LATEST" ] && { echo "ERR: no backup file"; exit 1; }
log "candidate: $LATEST"

age -d -i "$AGE_KEY_FILE" -o "$WORK_DIR/restore.tar" "$LATEST"
tar xf "$WORK_DIR/restore.tar" -C "$WORK_DIR"
EXTRACTED=$(ls -d "$WORK_DIR"/*/ | head -1)
log "extracted: $EXTRACTED"

mkdir -p "$STANDBY_DATA"
chmod 700 "$STANDBY_DATA"

# Start fresh standby container if not running
if ! docker ps --format '{{.Names}}' | grep -qx "$STANDBY_CONTAINER"; then
  log "starting standby container :$PG_PORT"
  docker run -d --name "$STANDBY_CONTAINER" \
    -e POSTGRES_PASSWORD="standby-$(openssl rand -hex 8)" \
    -e POSTGRES_USER=standby \
    -e POSTGRES_DB=postgres \
    -v "$STANDBY_DATA":/var/lib/postgresql/data \
    -p "127.0.0.1:$PG_PORT:5432" \
    postgres:$PG_VERSION
  # wait for ready
  for i in 1 2 3 4 5 6 7 8 9 10; do
    docker exec "$STANDBY_CONTAINER" pg_isready -U standby >/dev/null 2>&1 && break
    sleep 2
  done
fi

# Restore each pg dump
for dump in "$EXTRACTED"/pg_*.sql.gz; do
  [ -f "$dump" ] || continue
  name=$(basename "$dump" .sql.gz)
  log "restore $name"
  zcat "$dump" | docker exec -i "$STANDBY_CONTAINER" psql -U standby -d postgres 2>&1 | tail -5
done

log "=== standby ready on localhost:$PG_PORT (user=standby) ==="
log "next steps for failover: see ~/Desktop/Codex/ai-control-plane/docs/dr-failover.md"
