#!/bin/bash
# oneflow-backup.sh — daily encrypted backup of OneFlow stack
# Runs on Flash. Targets: PostgreSQL ×3, Redis/Valkey ×3, Meilisearch, Chibisafe data,
# /root/.credentials, /root/workspace selected dirs, /etc selected dirs.
# Output: age-encrypted tarball in /var/backups/oneflow/ + sync to /mac (SSHFS).
#
# Restore: see /usr/local/bin/oneflow-restore-drill.sh
# Last updated: 2026-05-03 (P0 #1 vibe-coding implementation)
set -euo pipefail
shopt -s nullglob

# ---- Config ----
DATE=$(date -u +%Y%m%d_%H%M%S)
WORK_ROOT=/var/backups/oneflow
WORK_DIR="$WORK_ROOT/$DATE"
LOG_FILE=/var/log/oneflow-backup.log
RETENTION_LOCAL_DAYS=7
RETENTION_MAC_DAYS=30
AGE_RECIPIENT="age1kdwk247yuxsx5rxtel32j2ksz6pc9vk40c5cf7c3zkyduxzxf3yqv5clcd"
AGE_KEY_FILE=/root/.config/sops/age/keys.txt
MAC_TARGET=/mac/Documents/oneflow-backups
NTFY_URL="https://ntfy.oneflow.cz/Filip"
START_TS=$(date +%s)

# ---- Logging ----
log() { echo "[$(date -u +%H:%M:%SZ)] $*" | tee -a "$LOG_FILE"; }
fail() { log "FAIL: $*"; notify "❌ Backup FAIL ($DATE): $*" 5; exit 1; }
notify() {
  local msg="$1"
  local priority="${2:-3}"
  curl -sf -d "$msg" -H "Priority: $priority" -H "Tags: floppy_disk,oneflow" "$NTFY_URL" >/dev/null 2>&1 || true
}

mkdir -p "$WORK_DIR" "$WORK_ROOT" "$(dirname "$LOG_FILE")"
chmod 700 "$WORK_ROOT" "$WORK_DIR"

log "=== oneflow-backup START $DATE ==="

# ---- Sanity checks ----
[ -r "$AGE_KEY_FILE" ] || fail "age key not readable: $AGE_KEY_FILE"
command -v age >/dev/null || fail "age not installed"
command -v docker >/dev/null || fail "docker not installed"
[ -d "$MAC_TARGET" ] || log "WARN: $MAC_TARGET not mounted; backup stays local only"

# ---- 1. PostgreSQL dumps ----
backup_pg() {
  local container="$1"
  local user="$2"
  local out="$WORK_DIR/pg_${container}.sql.gz"
  if docker ps --format '{{.Names}}' | grep -qx "$container"; then
    log "pg_dumpall $container (user=$user)"
    if docker exec "$container" pg_dumpall -U "$user" 2>>"$LOG_FILE" | gzip > "$out"; then
      local size; size=$(du -h "$out" | cut -f1)
      log "  ok: $out ($size)"
    else
      log "  WARN: pg_dumpall $container failed (continuing)"
    fi
  else
    log "skip pg: $container not running"
  fi
}
backup_pg postgres            admin
backup_pg postiz-postgres     postiz-user
backup_pg glitchtip-postgres-1 glitchtip

# ---- 2. Redis / Valkey snapshots ----
backup_redis() {
  local container="$1"
  local cli="${2:-redis-cli}"
  local rdb_path="${3:-/data/dump.rdb}"
  local out="$WORK_DIR/redis_${container}.rdb"
  if docker ps --format '{{.Names}}' | grep -qx "$container"; then
    log "BGSAVE $container ($cli)"
    docker exec "$container" "$cli" BGSAVE >/dev/null 2>&1 || log "  BGSAVE $container failed (continuing)"
    sleep 5
    if docker cp "$container:$rdb_path" "$out" 2>>"$LOG_FILE"; then
      gzip -f "$out"
      log "  ok: ${out}.gz"
    else
      log "  WARN: docker cp $container:$rdb_path failed"
    fi
  else
    log "skip redis: $container not running"
  fi
}
backup_redis valkey            valkey-cli
backup_redis glitchtip-redis-1 redis-cli
backup_redis postiz-redis      redis-cli

# ---- 3. Meilisearch & Chibisafe data (Docker volume tar) ----
backup_volume() {
  local volume="$1"
  local label="${2:-$volume}"
  local out="$WORK_DIR/volume_${label}.tar.gz"
  if docker volume inspect "$volume" >/dev/null 2>&1; then
    log "tar volume $volume"
    docker run --rm -v "$volume":/source:ro -v "$WORK_DIR":/dst alpine \
      sh -c "cd /source && tar czf /dst/volume_${label}.tar.gz . 2>/dev/null" \
      || log "  WARN: tar volume $volume failed"
    [ -f "$out" ] && log "  ok: $out ($(du -h "$out" | cut -f1))"
  else
    log "skip volume: $volume not found"
  fi
}
# Auto-detect common OneFlow volumes; missing ones are silently skipped.
for vol in $(docker volume ls -q 2>/dev/null | grep -E '^(meilisearch|chibisafe|postiz|glitchtip|open-archiver)'); do
  backup_volume "$vol"
done

# ---- 4. SQLite databases (filesystem walk) ----
log "scan SQLite under /root/workspace"
SQLITE_DIR="$WORK_DIR/sqlite"
mkdir -p "$SQLITE_DIR"
SQLITE_COUNT=0
while IFS= read -r -d '' db; do
  rel=$(echo "$db" | sed 's|/root/workspace/||;s|/|__|g')
  cp -p "$db" "$SQLITE_DIR/$rel" 2>/dev/null && SQLITE_COUNT=$((SQLITE_COUNT+1)) || true
done < <(find /root/workspace -maxdepth 6 \( -name "*.db" -o -name "*.sqlite" -o -name "*.sqlite3" \) -size +0 -print0 2>/dev/null)
log "  copied $SQLITE_COUNT sqlite files"

# ---- 5. Configuration & credentials snapshot ----
log "tar config dirs"
CONFIG_TAR="$WORK_DIR/configs.tar.gz"
tar czf "$CONFIG_TAR" \
  /root/.credentials \
  /root/.config/sops \
  /root/.sops.yaml \
  /root/.ssh \
  /etc/postfix \
  /etc/opendkim \
  /etc/dovecot \
  /etc/wireguard \
  /etc/caddy \
  /etc/prometheus \
  /etc/alertmanager \
  /etc/promtail \
  /etc/loki \
  /etc/systemd/system/oneflow-*.service \
  /etc/systemd/system/oneflow-*.timer \
  /usr/local/bin/oneflow-*.sh \
  /usr/local/bin/sops-load.sh \
  2>>"$LOG_FILE" || log "  some config paths missing (ok)"
log "  ok: $CONFIG_TAR ($(du -h "$CONFIG_TAR" | cut -f1))"

# ---- 6. App workspace snapshot (selected) ----
log "tar app workspace (selected dirs only)"
APPS_TAR="$WORK_DIR/apps_workspace.tar.gz"
tar czf "$APPS_TAR" \
  --exclude='*.log' --exclude='*.pyc' --exclude='__pycache__' --exclude='node_modules' \
  --exclude='.venv' --exclude='venv' --exclude='.next' --exclude='dist' \
  -C / \
  $(ls -d /root/workspace/*/ 2>/dev/null | head -20 | sed 's|^/||;s|/$||') \
  2>>"$LOG_FILE" || log "  workspace tar partial (ok)"
log "  ok: $APPS_TAR ($(du -h "$APPS_TAR" | cut -f1 || echo n/a))"

# ---- 7. Manifest ----
{
  echo "backup_id: $DATE"
  echo "host: $(hostname)"
  echo "kernel: $(uname -r)"
  echo "docker_version: $(docker --version)"
  echo "containers_running:"
  docker ps --format '  - {{.Names}}: {{.Image}} ({{.Status}})'
  echo "files:"
  (cd "$WORK_DIR" && ls -la | tail -n +2)
  echo "total_size: $(du -sh "$WORK_DIR" | cut -f1)"
} > "$WORK_DIR/MANIFEST.txt"

# ---- 8. Encrypt single tarball ----
log "encrypt tarball with age"
PLAIN_TAR="$WORK_ROOT/oneflow-${DATE}.tar"
ENC_FILE="$WORK_ROOT/oneflow-${DATE}.tar.age"
tar cf "$PLAIN_TAR" -C "$WORK_ROOT" "$DATE" 2>>"$LOG_FILE"
PLAIN_SIZE=$(du -h "$PLAIN_TAR" | cut -f1)
age -r "$AGE_RECIPIENT" -o "$ENC_FILE" "$PLAIN_TAR"
ENC_SIZE=$(du -h "$ENC_FILE" | cut -f1)
chmod 600 "$ENC_FILE"
shred -u "$PLAIN_TAR" 2>/dev/null || : > "$PLAIN_TAR"
rm -rf "$WORK_DIR"  # cleanup unencrypted dir
log "  encrypted: $ENC_FILE (plain=$PLAIN_SIZE → enc=$ENC_SIZE)"

# ---- 9. Sync to Mac via SSHFS ----
if [ -d "$MAC_TARGET" ]; then
  log "rsync to $MAC_TARGET"
  if rsync -a --partial "$ENC_FILE" "$MAC_TARGET/" 2>>"$LOG_FILE"; then
    log "  ok: synced to Mac"
  else
    log "  WARN: rsync to Mac failed"
  fi
fi

# ---- 10. Retention ----
log "retention prune"
find "$WORK_ROOT" -maxdepth 1 -name "oneflow-*.tar.age" -mtime +$RETENTION_LOCAL_DAYS -delete 2>/dev/null || true
[ -d "$MAC_TARGET" ] && find "$MAC_TARGET" -maxdepth 1 -name "oneflow-*.tar.age" -mtime +$RETENTION_MAC_DAYS -delete 2>/dev/null || true

# ---- 11. Notify ----
DURATION=$(($(date +%s) - START_TS))
log "=== DONE ($DURATION s, enc=$ENC_SIZE) ==="
notify "✅ Backup OK $DATE — ${ENC_SIZE} in ${DURATION}s" 3
