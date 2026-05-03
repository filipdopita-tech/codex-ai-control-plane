# DR Failover Runbook — OneFlow PostgreSQL Warm Standby

**Last updated:** 2026-05-03 (P0 #5 vibe-coding implementation)
**Owner:** Filip Dopita
**Tier:** P0 — single Flash failure protection

---

## Architecture

```
┌─────────────────────┐                   ┌──────────────────────┐
│  Flash VPS (PROD)   │  daily backup     │  Mac (warm standby)  │
│                     │ ─────────────────►│                      │
│  postgres           │  age-encrypted    │  oneflow-pg-standby  │
│  postiz-postgres    │  via SSHFS /mac   │  (Docker, port 15432)│
│  glitchtip-pg-1     │  + WG tunnel      │                      │
│                     │                   │  ~/Library/          │
│  /var/backups/      │                   │   oneflow-pg-standby │
└─────────────────────┘                   └──────────────────────┘
```

**RTO** (Recovery Time Objective): ≤30 min cold-restore, ≤5 min if standby pre-warmed.
**RPO** (Recovery Point Objective): ≤24h (last successful backup).

To improve to RPO <5s + RTO <2min, enable streaming replication (Step 5 below — opt-in, requires prod-PG restart).

---

## Daily warm-standby refresh (Mac)

Add to Mac crontab so the standby is always within 24h of prod:

```bash
# crontab -e (Mac)
30 3 * * * /Users/filipdopita/Desktop/Codex/ai-control-plane/scripts/oneflow-pg-standby-restore.sh >> ~/Library/Logs/oneflow-pg-standby.log 2>&1
```

What it does:
1. Picks newest `~/Documents/oneflow-backups/oneflow-*.tar.age`
2. age-decrypts → extracts `pg_*.sql.gz`
3. Starts (or reuses) Docker container `oneflow-pg-standby` on port 15432
4. Restores all 3 dumps into the standby cluster

After first run, the standby has up-to-date data and can be promoted in minutes.

---

## Disaster scenario A — Flash hardware/disk failure (data lost on prod)

**Symptom:** `oneflow.cz` and apps return 502/down, ssh to Flash unreachable, ntfy `HostDown` alert fired.

### Steps

1. **Confirm Flash is unrecoverable** (Contabo console → VPS status, attempt reboot via panel). If it boots, skip to scenario B.

2. **Promote Mac standby** (these run on Mac):
   ```bash
   # 2.1 Ensure standby has latest backup loaded
   ~/Desktop/Codex/ai-control-plane/scripts/oneflow-pg-standby-restore.sh

   # 2.2 Verify data is there
   docker exec oneflow-pg-standby psql -U standby -l   # list databases
   docker exec oneflow-pg-standby psql -U standby -d open_archive -c "SELECT count(*) FROM pg_stat_user_tables;"

   # 2.3 Re-expose standby on WG IP for apps
   docker stop oneflow-pg-standby
   docker rm oneflow-pg-standby
   docker run -d --name oneflow-pg-standby \
     -v ~/Library/oneflow-pg-standby:/var/lib/postgresql/data \
     -p 10.77.0.2:5432:5432 \
     -e POSTGRES_PASSWORD=$(cat ~/.credentials/oneflow-pg-standby-pass) \
     -e POSTGRES_USER=standby \
     postgres:15
   ```

3. **Spin up replacement Flash** (new Contabo VPS or Hetzner):
   - Pre-provisioned image, or `cloud-init` from `infra/flash-bootstrap.sh`
   - Restore configs from backup `configs.tar.gz`:
     ```bash
     scp ~/Documents/oneflow-backups/oneflow-*.tar.age newhost:/tmp/
     ssh newhost
     age -d -i /root/.config/sops/age/keys.txt /tmp/oneflow-*.tar.age | tar x
     # Apply /etc/postfix, /etc/wireguard, /etc/caddy, /root/.credentials, etc.
     ```
   - Apps reconnect to Mac PG via WG IP `10.77.0.2:5432` initially, then back to local once data sync completes.

4. **Re-sync apps to point at standby**:
   - Update each app's `DATABASE_URL` to `postgres://standby:$pass@10.77.0.2:5432/{db}`
   - Restart containers via `docker compose up -d`

5. **Document the incident** in `~/Desktop/Codex/incidents/YYYY-MM-DD-flash-failure.md`.

**Validation:**
- `oneflow.cz` returns 200
- ntfy `HostDown` clears
- `restore-drill` next Sunday confirms backup chain integrity

---

## Disaster scenario B — Accidental DROP / corruption (Flash up, data corrupt)

**Symptom:** Specific table empty, app errors with foreign key violations, query returns wrong data.

### Steps

1. **Stop writes immediately** (read-only mode):
   ```bash
   ssh root@10.77.0.1
   docker exec postgres psql -U admin -c "ALTER DATABASE open_archive SET default_transaction_read_only = on;"
   ```

2. **Pull latest backup** (the daily one is your best snapshot):
   ```bash
   ls -lt /var/backups/oneflow/oneflow-*.tar.age | head -3
   ```

3. **Spin up restore-test container** (don't touch prod yet):
   ```bash
   age -d -i /root/.config/sops/age/keys.txt /var/backups/oneflow/oneflow-LATEST.tar.age | tar xC /tmp/restore
   docker run -d --name pg-restore-test -p 127.0.0.1:15433:5432 -e POSTGRES_PASSWORD=test postgres:15
   docker exec -i pg-restore-test psql -U postgres < /tmp/restore/*/pg_postgres.sql.gz   # adjust as needed
   ```

4. **Verify expected data exists** in restore-test container (count rows, sample queries).

5. **Selective restore into prod** (table-by-table, NOT full restore):
   ```bash
   # Example: restore single table from test to prod
   docker exec pg-restore-test pg_dump -U postgres -t my_table -d open_archive | \
     docker exec -i postgres psql -U admin -d open_archive
   ```

6. **Lift read-only**:
   ```bash
   docker exec postgres psql -U admin -c "ALTER DATABASE open_archive SET default_transaction_read_only = off;"
   ```

---

## Step 5 (OPT-IN) — Streaming replication for hot standby

This upgrades RPO from 24h to ~5s but requires:
- Prod PG container restart (~10s downtime)
- Mac to run a postgres process listening on WG (10.77.0.2:5432)
- WireGuard NAT/firewall allows Flash → Mac on tcp:5432

### A) On Flash (master) — `docker exec` into prod postgres container

```bash
docker exec -it postgres psql -U admin -d postgres <<'SQL'
ALTER SYSTEM SET wal_level = replica;
ALTER SYSTEM SET max_wal_senders = 3;
ALTER SYSTEM SET wal_keep_size = '1GB';
ALTER SYSTEM SET hot_standby = on;
CREATE ROLE replicator WITH LOGIN REPLICATION PASSWORD 'PUT-STRONG-PASSWORD-HERE';
SELECT pg_reload_conf();
SQL

# Update pg_hba.conf inside container to allow replicator from 10.77.0.2/32
docker exec postgres bash -c "echo 'host replication replicator 10.77.0.2/32 scram-sha-256' >> /var/lib/postgresql/data/pg_hba.conf"
docker restart postgres
```

### B) On Mac (standby) — pg_basebackup from Flash

```bash
mkdir -p ~/Library/oneflow-pg-streaming
chmod 700 ~/Library/oneflow-pg-streaming

# Run as postgres user inside container, but pull data first via host pg_basebackup
docker run --rm -v ~/Library/oneflow-pg-streaming:/var/lib/postgresql/data \
  -e PGPASSWORD='PUT-STRONG-PASSWORD-HERE' \
  postgres:15 \
  pg_basebackup -h 10.77.0.1 -U replicator -D /var/lib/postgresql/data -P -R -X stream

# Now start the streaming standby
docker run -d --name oneflow-pg-streaming-standby \
  -v ~/Library/oneflow-pg-streaming:/var/lib/postgresql/data \
  -p 10.77.0.2:5432:5432 \
  postgres:15
```

### C) Verify replication lag

```bash
# On Flash — check replicator connection is active
docker exec postgres psql -U admin -c "SELECT * FROM pg_stat_replication;"
# Expected: 1 row, state=streaming, sync_state=async, write_lag <1s
```

### D) Failover (manual promote)

When Flash dies:
```bash
# On Mac
docker exec oneflow-pg-streaming-standby psql -U postgres -c "SELECT pg_promote();"
# Mac PG is now read-write master, switch app DATABASE_URLs to 10.77.0.2:5432
```

---

## Recovery Time / Point Objectives summary

| Scenario | RPO | RTO | Method |
|---|---|---|---|
| Daily backup + cold restore | 24h | 30 min | Default (this implementation) |
| Daily backup + pre-warmed standby | 24h | 5 min | Run `oneflow-pg-standby-restore.sh` daily |
| Streaming replication | <5s | 2 min | Step 5 above (opt-in) |

---

## Quarterly DR test

Last Sunday of each quarter, run promotion drill:
1. Promote Mac standby (read-only check) — no apps switched
2. Verify row counts match a known query against current prod
3. Demote standby (drop container, restart from backup)
4. Document result in `~/Desktop/Codex/dr-tests/YYYY-Q?-test.md`

ntfy notification on PASS/FAIL via `/usr/local/bin/oneflow-restore-drill.sh` (which already runs weekly Sunday 03:30 UTC).
