#!/bin/bash
# oneflow-pg-flash-standby.sh — secondary PG container on Flash itself.
# Loads latest backup into a separate `postgres-standby` container on port 15432.
# Defense for scenario B (accidental DROP / corruption): in <10 min Filip can switch
# DATABASE_URL to standby, query missing data, selectively restore.
# Hardware-failure defense remains the off-site Mac backup.
set -euo pipefail

DATE=$(date -u +%Y%m%d_%H%M%S)
WORK_DIR=$(mktemp -d /tmp/pg-flash-standby.XXXXXX)
AGE_KEY_FILE=/root/.config/sops/age/keys.txt
STANDBY_DATA=/var/lib/oneflow-pg-standby
STANDBY_NAME=postgres-standby
PG_VERSION=15
PG_PORT=15432
LOG_FILE=/var/log/oneflow-pg-flash-standby.log
START_TS=$(date +%s)

log() { echo "[$(date -u +%H:%M:%SZ)] $*" | tee -a "$LOG_FILE"; }
cleanup() { rm -rf "$WORK_DIR" 2>/dev/null || true; }
trap cleanup EXIT

log "=== flash-side standby refresh start ($DATE) ==="

LATEST=$(ls -t /var/backups/oneflow/oneflow-*.tar.age 2>/dev/null | head -1 || true)
[ -z "$LATEST" ] && { log "ERR no backup"; exit 1; }
log "candidate: $(basename "$LATEST")"

age -d -i "$AGE_KEY_FILE" -o "$WORK_DIR/restore.tar" "$LATEST"
tar xf "$WORK_DIR/restore.tar" -C "$WORK_DIR"
EXTRACTED=$(ls -d "$WORK_DIR"/*/ | head -1)
log "extracted"

mkdir -p "$STANDBY_DATA"
chmod 700 "$STANDBY_DATA"

# Stop + remove previous standby (atomic refresh)
docker stop "$STANDBY_NAME" 2>/dev/null || true
docker rm "$STANDBY_NAME" 2>/dev/null || true
# Reset data dir for clean restore
find "$STANDBY_DATA" -mindepth 1 -delete 2>/dev/null || true

PG_PASS=$(openssl rand -hex 16)
echo "$PG_PASS" > /etc/oneflow-pg-standby.pass && chmod 600 /etc/oneflow-pg-standby.pass

docker run -d --name "$STANDBY_NAME" \
  -e POSTGRES_PASSWORD="$PG_PASS" \
  -e POSTGRES_USER=standby \
  -e POSTGRES_DB=postgres \
  -v "$STANDBY_DATA":/var/lib/postgresql/data \
  -p "127.0.0.1:$PG_PORT:5432" \
  --restart=unless-stopped \
  postgres:$PG_VERSION >/dev/null

# Wait for ready
for i in $(seq 1 20); do
  docker exec "$STANDBY_NAME" pg_isready -U standby >/dev/null 2>&1 && break
  sleep 2
done

RESTORED=0
for dump in "$EXTRACTED"/pg_*.sql.gz; do
  [ -f "$dump" ] || continue
  name=$(basename "$dump" .sql.gz | sed 's/^pg_//')
  log "restore $name"
  if zcat "$dump" | docker exec -i "$STANDBY_NAME" psql -U standby -d postgres >/dev/null 2>&1; then
    RESTORED=$((RESTORED+1))
    log "  ok"
  else
    log "  WARN partial restore"
  fi
done

DURATION=$(($(date +%s) - START_TS))

# Textfile metric
TF=/var/lib/node_exporter/textfile_collector/oneflow_pg_standby.prom
mkdir -p "$(dirname "$TF")"
cat > "$TF.tmp" <<EOF
# HELP oneflow_pg_standby_last_refresh_timestamp_seconds Unix time of last standby refresh
# TYPE oneflow_pg_standby_last_refresh_timestamp_seconds gauge
oneflow_pg_standby_last_refresh_timestamp_seconds $(date +%s)
# HELP oneflow_pg_standby_dumps_restored Count of pg_*.sql.gz dumps successfully restored
# TYPE oneflow_pg_standby_dumps_restored gauge
oneflow_pg_standby_dumps_restored $RESTORED
# HELP oneflow_pg_standby_refresh_duration_seconds Duration of last refresh
# TYPE oneflow_pg_standby_refresh_duration_seconds gauge
oneflow_pg_standby_refresh_duration_seconds $DURATION
EOF
mv -f "$TF.tmp" "$TF"
chmod 644 "$TF"

log "=== DONE (${DURATION}s, $RESTORED dumps restored, port=$PG_PORT) ==="
curl -sf -X POST -H "Authorization: Bearer $(grep -oE 'NTFY_TOKEN=.*' /run/oneflow-secrets.env 2>/dev/null | cut -d= -f2 || echo '')" \
  -H "Title: PG Standby refreshed" -H "Priority: 2" -H "Tags: floppy_disk" \
  -d "Standby refresh: $RESTORED dumps in ${DURATION}s, port=$PG_PORT" \
  "https://ntfy.oneflow.cz/Filip" >/dev/null 2>&1 || true
