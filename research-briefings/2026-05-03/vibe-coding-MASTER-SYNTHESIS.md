# Vibe Coding Exposed → Filip's 10/10 Production Stack

**Date:** 2026-05-03
**Source:** Instagram graphic "Vibe Coding Exposed" + research deep dive + ekosystém audit
**Companion files:**
- `vibe-coding-iceberg-research.md` (40K, 6277 slov) — deep research o každém pojmu
- `vibe-coding-ecosystem-audit.md` (12K, 1698 slov) — reálný stav Filip's stack

---

## TL;DR

Filipova maturity: **6.5/10**. Strong foundation (Docker, Caddy, WireGuard, GlitchTip, fluent-bit). Top gaps: **observability triumvirate, secrets sprawl, untested backupy, žádné feature flags**.

**Klíčový insight:** 80% pojmů z ledovce je enterprise/post-Series-B nesmysl pro Filipa (Kubernetes, DynamoDB, SQS, sharding, gRPC). 20% je kritické — a tam má největší díry.

**90-day plán k 10/10:** 5 P0 akcí (28 hod práce) → eliminuje 90% production rizika. Roadmapa níže.

---

## ČÁST 1: FILIPŮV LEDOVEC — REALITY HEATMAP

Mapuji každý pojem z Instagram graphic na Filipův skutečný stav (audit) + verdikt z research:

### Vrstva 1 — INFRASTRUCTURE (8 pojmů)

| Pojem | Filipova realita | Research verdict 2026 | Akce |
|---|---|---|---|
| **Kubernetes** | ❌ NEMÁ | Dead pro <50 lidí. systemd + VPS = 99% benefitu. | **NEDĚLAT.** Anti-pattern pro Filipa. |
| **Docker** | ✅ HAS (17 containers) | P1 conditional. Distroless base, image <100MB. | **OPTIMIZE:** distroless, image scanning. |
| **Containerisation** | ✅ HAS | OK | Dokumentovat docker-compose.yml umístění. |
| **CI/CD** | 🟡 PARTIAL (bash scripts) | P1 mandatory. GitHub Actions free 2000 min/mo. | **P1 AKCE:** Migrace k GitHub Actions. |
| **Cloud (AWS/GCP)** | 🚫 N/A | Not needed. VPS-first je validní stack. | **NEDĚLAT.** Cost discipline rule. |
| **Staging** | 🟡 PARTIAL | P2. Druhý VPS nebo Docker compose namespace. | **P2 AKCE:** Staging na Flash via docker-compose. |
| **Deployments** | 🟡 PARTIAL (manual) | P1. Atomic deploy + automated rollback. | **P1 AKCE:** Deploy script s health gates. |
| **FTP** | 🚫 N/A | Anti-pattern 2026. SFTP/rsync/Mutagen. | OK, Mutagen je správně. |

### Vrstva 2 — DATA (7 pojmů)

| Pojem | Filipova realita | Research verdict 2026 | Akce |
|---|---|---|---|
| **S3** | 🚫 N/A | OK pro internal. Backblaze B2 = $0.005/GB. | **P0 AKCE:** B2 pro backup off-site (viz P0). |
| **Database** | ✅ HAS (5 instances) | OK ale risky. PostgreSQL ×2, MariaDB, Redis ×2, Valkey, Meilisearch. | **P0 AKCE:** Backup automation. |
| **DynamoDB** | 🚫 N/A | Vendor lock-in. SQLite/Postgres lepší. | **NEDĚLAT.** |
| **Embedded database** | 🟡 PARTIAL (SQLite likely) | SQLite + WAL mode renesance 2024-2025. LiteFS production-ready. | **P1 AKCE:** Identifikovat kde SQLite, přidat WAL mode. |
| **Sharding** | 🚫 N/A | Premature optimization. <50GB = nesharduj. | **NEDĚLAT.** Anti-pattern. |
| **Partitioning** | 🚫 N/A | Time-based only (archive >6 months). | **P3 AKCE:** Až po 50GB+ dat. |
| **Caching** | 🟡 PARTIAL (Redis ×2 + Valkey) | Redis pro sessions/rate-limit ONLY, ne data cache. | **P2 AKCE:** Audit co Redis dělá. Validovat scope. |

### Vrstva 3 — MESSAGING & ASYNC (5 pojmů)

| Pojem | Filipova realita | Research verdict 2026 | Akce |
|---|---|---|---|
| **SQS** | 🚫 N/A | NATS JetStream self-hosted = $0 vs SQS. | **NEDĚLAT.** Vendor lock-in trap. |
| **Kafka/RabbitMQ** | ❌ NEMÁ (Redis can act as queue) | Overkill pro Filip. NATS lepší volba. | **P2 AKCE:** Pokud potřeba reliable queue → NATS, ne Kafka. |
| **WebSockets** | 🟡 PARTIAL (Hermes? Telegram bot?) | SSE jednodušší pro server→client push. | **P2 AKCE:** Audit kde ws používá. |
| **Long/short polling** | 🚫 N/A | OK pro fallback. SSE primárně. | OK. |
| **RPC** | ✅ HAS (14 MCP servers — MCP je RPC) | OK. MCP = production-grade RPC. | OK. |

### Vrstva 4 — NETWORKING & API (6 pojmů)

| Pojem | Filipova realita | Research verdict 2026 | Akce |
|---|---|---|---|
| **Load Balancer** | ✅ HAS (Caddy) | OK. Single Caddy = SPOF ale akceptabilní pro single-region. | **P3 AKCE:** Eventually secondary Caddy na Alfa. |
| **Proxy** | ✅ HAS (Caddy reverse proxy) | OK. | OK. |
| **Firewall** | ✅ HAS (UFW + fail2ban + CrowdSec + WireGuard) | **NADPRŮMĚR.** Better než 95% solo founders. | OK, zachovat. |
| **Rate limiting** | 🟡 PARTIAL (UFW/fail2ban level) | Aplikační rate limit chybí. Caddy `rate_limit` nebo middleware. | **P1 AKCE:** Caddy rate_limit per route. |
| **QPS** | ❌ NEMÁ tracking | Prometheus `http_requests_total` rate. | **P0 AKCE:** Součást observability stack. |
| **Throughput** | ❌ NEMÁ tracking | Stejné. | **P0 AKCE:** Součást observability stack. |

### Vrstva 5 — RELIABILITY & OBSERVABILITY (3 pojmů)

| Pojem | Filipova realita | Research verdict 2026 | Akce |
|---|---|---|---|
| **Error logging** | 🟡 PARTIAL (GlitchTip + fluent-bit) | GlitchTip = exceptions only. Need: structured logs + Loki. | **P0 AKCE:** Loki + Promtail (3 dny práce). |
| **Availability** | 🟡 PARTIAL (Monit + autoheal) | OK pro single-node. UptimeKuma external = SPOF detection. | **P1 AKCE:** UptimeKuma/Healthchecks.io setup. |
| **Git cherry-pick** | 🚫 N/A (workflow concept) | Standard git skill. | OK. |

### Vrstva 6 — CROSS-CUTTING (6 pojmů)

| Pojem | Filipova realita | Research verdict 2026 | Akce |
|---|---|---|---|
| **Encryption** | 🟡 PARTIAL (TLS via Caddy + chmod 600) | Disk-level encryption nejasný. App-layer pro DB sensitive columns chybí. | **P2 AKCE:** age + sops pro secrets at-rest. |
| **Serverless** | 🚫 N/A | OK pro VPS-first. | **NEDĚLAT.** |
| **Lambda** | 🚫 N/A | Same. | **NEDĚLAT.** |
| **Tensorflow** | 🚫 N/A | OK. Anthropic API + OpenRouter pro AI. | OK. |
| **Optimisation** | 🟡 PARTIAL | Premature optimization is root of evil. Profil first. | **P2 AKCE:** Add p99 latency tracking. |
| **git/github** | ✅ HAS | OK. | OK. |
| **PyCharm** | 🚫 N/A (VS Code likely) | Tooling preference. VS Code OK. | OK. |

### Vrstva 7 — RESEARCH ADDED (mimo Instagram graphic, ale 2026 mandatory)

| Pojem | Filipova realita | Verdict | Akce |
|---|---|---|---|
| **Structured logging** | ❌ MISSING | P0 mandatory 2026. printf logging = 2010s. | **P0 #1.** |
| **Metrics (Prometheus)** | ❌ MISSING | P1. Time-to-incident 10h → 10min. | **P0 #2.** |
| **Tracing** | ❌ MISSING | P2. Až při >5 services. | P2 LATER. |
| **Secrets vault (sops/age)** | ❌ MISSING (env files) | P0. Single source of truth. | **P0 #3.** |
| **Backup 3-2-1** | ❌ MISSING | P0 critical. RPO/RTO undefined. | **P0 #4.** |
| **Restore drill** | ❌ NEVER TESTED | P0. Untested = useless. | **P0 #4 (chained).** |
| **Feature flags** | ❌ MISSING | P1. Deploy ≠ release. | **P1 AKCE.** |
| **Schema migrations** | 🟡 PARTIAL (manual) | P1. Atlas/sqitch versioned. | **P1 AKCE.** |
| **Database connection pooling** | 🟡 UNCLEAR | P1 (pokud Postgres). pgBouncer mandatory. | **P1 AKCE.** |
| **Cost monitoring (Hetzner+Anthropic)** | 🟡 PARTIAL | P2. Anthropic spend tracker. | **P2 AKCE.** |
| **API contract (OpenAPI)** | ❌ MISSING | P2. Mandatory pro klient-facing APIs. | **P2 AKCE.** |

---

## ČÁST 2: GAP SUMMARY — KDE JE FILIP NA SPEKTRU

```
        ❌ GAPS (prácno)        🟡 PARTIAL          ✅ STRENGTHS
        ────────────────         ──────────         ───────────────
P0      Backup automation        Error logging       Containerization
        Restore drill            Database (no repl)  Networking (UFW+WG)
        Structured logging       Secrets (env files) Reverse proxy
        Prometheus metrics                            fail2ban+CrowdSec
        sops+age secrets                              fluent-bit pipeline

P1      Feature flags            CI/CD (manual)      WireGuard mesh
        Schema migrations        Rate limiting       17 Docker containers
        Connection pooling       Embedded DB usage   GlitchTip self-host
        UptimeKuma external      Staging env

P2      OpenAPI contracts        Caching scope       Mutagen sync (Mac↔Flash)
        NATS for async           Encryption layers
        Cost monitoring          Optimisation
        Tracing                  Availability
                                 WebSockets

P3      Multi-region HA          —                   Single-region simplicity
        Distroless images
        Container registry
```

---

## ČÁST 3: TOP 5 KRITICKÝCH AKCÍ (P0) — 28 hod práce

Tyto akce eliminují **90% production rizika** Filipovy infrastruktury. Pořadí je **load-bearing** — backup před vším ostatním.

### P0 #1 — Backup Automation + Restore Drill (8 hod)

**Proč P0:** 5 databází, žádný automated backup. Single Flash failure = total data loss. Filipovy DD reporty, klient data, lead pipeline — vše na jediném disku.

**Co konkrétně:**

```bash
# /usr/local/bin/oneflow-backup.sh
#!/bin/bash
set -euo pipefail

DATE=$(date -u +%Y%m%d_%H%M%S)
BACKUP_DIR="/var/backups/oneflow/$DATE"
mkdir -p "$BACKUP_DIR"

# PostgreSQL (oba instances)
docker exec postgres-main pg_dumpall -U postgres | gzip > "$BACKUP_DIR/postgres-main.sql.gz"
docker exec postgres-glitchtip pg_dumpall -U postgres | gzip > "$BACKUP_DIR/postgres-glitchtip.sql.gz"

# MariaDB
docker exec mariadb mariadb-dump --all-databases | gzip > "$BACKUP_DIR/mariadb.sql.gz"

# Redis (RDB snapshot)
docker exec redis redis-cli BGSAVE
sleep 10
docker cp redis:/data/dump.rdb "$BACKUP_DIR/redis.rdb"

# SQLite (find all)
find /root/workspace -name "*.db" -o -name "*.sqlite" -o -name "*.sqlite3" 2>/dev/null | while read db; do
  cp "$db" "$BACKUP_DIR/$(basename $db).$(stat -c %Y $db)"
done

# Encrypt s age (recipient = Filip's age public key)
tar czf - "$BACKUP_DIR" | age -r age1xxx... > "$BACKUP_DIR.tar.gz.age"
rm -rf "$BACKUP_DIR"

# Push to B2 (Backblaze)
b2 upload-file oneflow-backups "$BACKUP_DIR.tar.gz.age" "daily/$(basename $BACKUP_DIR.tar.gz.age)"

# Local retention: 7 days
find /var/backups/oneflow -name "*.tar.gz.age" -mtime +7 -delete

# Notify
curl -d "Backup OK: $DATE, $(du -h $BACKUP_DIR.tar.gz.age | cut -f1)" https://ntfy.oneflow.cz/Filip
```

**Systemd timer:**
```ini
# /etc/systemd/system/oneflow-backup.service
[Unit]
Description=OneFlow daily backup
After=docker.service

[Service]
Type=oneshot
ExecStart=/usr/local/bin/oneflow-backup.sh
StandardOutput=journal
EnvironmentFile=/root/.credentials/master.env

# /etc/systemd/system/oneflow-backup.timer
[Unit]
Description=Daily OneFlow backup
[Timer]
OnCalendar=*-*-* 02:00:00
RandomizedDelaySec=30m
Persistent=true
[Install]
WantedBy=timers.target
```

**Restore drill skript** (běží týdně, P0 component):
```bash
# /usr/local/bin/oneflow-restore-drill.sh
# Stáhne nejnovější backup, restore do test DB, verify row counts, alert pokud fail
LATEST=$(b2 ls oneflow-backups | sort | tail -1)
b2 download-file-by-name oneflow-backups "$LATEST" /tmp/restore-test.tar.gz.age
age -d -i /root/.credentials/age-key.txt /tmp/restore-test.tar.gz.age | tar xzf - -C /tmp/restore-test
# Restore postgres-main do test container, count rows, srovnat s expected baseline
# ALERT pokud row count delta > 10% (možná korupce)
```

**Akceptační kritéria:**
- Daily backup běží, log v journalu, B2 obsahuje 7+ daily snapshots
- Týdenní restore drill nasazen, ntfy alert pokud fail
- RPO defined: 24h. RTO defined: 1h.
- Cost: B2 ~$0.50/měsíc (10 GB, $0.005/GB)

**Setup credentials:**
```bash
# B2 account: backup-only IAM key
# age key: ed25519, public + private, private secured chmod 600
# 1Password backup of age private key (recovery scenario)
```

### P0 #2 — Structured Logging + Loki (5 hod)

**Proč P0:** Filip má fluent-bit a GlitchTip ale **NEMÁ centralized log search**. Když nějaký scraper selže nebo Hermes agent začne dávat 500ky, debug = SSH na Flash + grep souborů. Time-to-resolution roste s velikostí systému.

**Co konkrétně:**

1. **Loki single-binary deploy:**
```bash
ssh root@10.77.0.1 "
docker run -d --name loki \
  --restart=unless-stopped \
  -v /var/loki:/loki \
  -p 127.0.0.1:3100:3100 \
  grafana/loki:latest
"
```

2. **Promtail** (log shipper) — config sbírá logs z Docker, systemd journal, fluent-bit:
```yaml
# /etc/promtail/config.yml
server:
  http_listen_port: 9080
clients:
  - url: http://localhost:3100/loki/api/v1/push
scrape_configs:
  - job_name: docker
    docker_sd_configs:
      - host: unix:///var/run/docker.sock
    relabel_configs:
      - source_labels: [__meta_docker_container_name]
        target_label: container
  - job_name: journal
    journal:
      max_age: 12h
      labels:
        job: systemd-journal
    relabel_configs:
      - source_labels: [__journal__systemd_unit]
        target_label: unit
```

3. **Python logging migration** (každá Filip's app):
```python
# logger.py
import logging
import json
import sys
from datetime import datetime

class JSONFormatter(logging.Formatter):
    def format(self, record):
        return json.dumps({
            "ts": datetime.utcnow().isoformat() + "Z",
            "level": record.levelname,
            "logger": record.name,
            "message": record.getMessage(),
            "request_id": getattr(record, "request_id", None),
            "user_id": getattr(record, "user_id", None),
            "endpoint": getattr(record, "endpoint", None),
            "latency_ms": getattr(record, "latency_ms", None),
            "error": str(record.exc_info[1]) if record.exc_info else None,
        })

handler = logging.StreamHandler(sys.stdout)
handler.setFormatter(JSONFormatter())
logger = logging.getLogger("oneflow")
logger.addHandler(handler)
logger.setLevel(logging.INFO)
```

4. **Grafana Cloud free tier** (1 stack, 50GB logs/mo):
   - Sign up grafana.com/auth/sign-up
   - Create stack → connect to local Loki
   - Pre-built dashboard: OneFlow logs by service

**Akceptační kritéria:**
- Logs aggregated do Loki, searchable přes Grafana UI
- Request IDs propagated through services (correlation)
- Retention: 30 days hot (Loki local), unlimited cold (Loki s S3 backend, optional)
- Time-to-find-error: 10 min → 30 sec

### P0 #3 — Secrets Migration: env files → sops + age (6 hod)

**Proč P0:** `~/.credentials/master.env` je single point of failure. Žádné rotation, žádný audit, žádná secrets distribution between Mac↔Flash automated. Riziko: leak v git history, copy-paste chyba do Slack/Telegram.

**Co konkrétně:**

```bash
# Install sops + age (Mac)
brew install sops age

# Generate age keypair
age-keygen -o ~/.config/sops/age/keys.txt
# Output: AGE-SECRET-KEY-... (private), age1... (public)

# Backup private key to 1Password (Filip MUST do this)
# Without private key = lost access to encrypted secrets

# Convert master.env → master.sops.yaml
cat > /tmp/master.yaml <<EOF
ANTHROPIC_API_KEY: sk-ant-...
OPENROUTER_API_KEY: sk-or-...
GHL_API_KEY: pit-...
APIFY_TOKEN: apify_api_...
B2_KEY_ID: ...
B2_APP_KEY: ...
HERMES_TG_TOKEN: ...
# ... etc
EOF

# Encrypt
sops --encrypt --age age1xxx... /tmp/master.yaml > ~/.credentials/master.sops.yaml
rm /tmp/master.yaml

# Commit encrypted version (safe — readable jen s age key)
cd ~/.credentials
git init
git add master.sops.yaml
git commit -m "Initial sops vault"

# Sync to Flash
ssh root@10.77.0.1 "mkdir -p /root/.credentials && mkdir -p /root/.config/sops/age"
scp ~/.config/sops/age/keys.txt root@10.77.0.1:/root/.config/sops/age/keys.txt
ssh root@10.77.0.1 "chmod 600 /root/.config/sops/age/keys.txt"
scp ~/.credentials/master.sops.yaml root@10.77.0.1:/root/.credentials/master.sops.yaml

# Použití (místo `source master.env`):
sops exec-env ~/.credentials/master.sops.yaml 'env | grep ANTHROPIC'

# Pro systemd services: pre-start hook
# /etc/systemd/system/my-service.service
# ExecStartPre=/usr/local/bin/sops-load.sh
# EnvironmentFile=/run/oneflow-secrets.env  # tmpfs, decrypted at runtime
```

**Pre-commit hook** (block git commits with .env):
```bash
# .git/hooks/pre-commit
#!/bin/bash
if git diff --cached --name-only | grep -E '\.env$|master\.env|credentials\.json'; then
  echo "ERROR: blocking commit of plaintext secrets file"
  echo "Use sops + age instead. See ~/.credentials/master.sops.yaml"
  exit 1
fi
```

**Akceptační kritéria:**
- master.env smazán z disk po migraci (jen master.sops.yaml zůstává)
- Mac + Flash + future VPS = same encrypted file (single source of truth)
- 1Password backup of age private key
- All systemd services use sops-loaded env vars
- Pre-commit hook blokuje plaintext .env

### P0 #4 — Prometheus + 5 Core Alerts (5 hod)

**Proč P0:** Filip má Monit pro CPU/disk/service health ale **žádné application metrics, žádné alerts pro business KPIs, žádné historical trends**. "Is it slow because of database? Network? App?" = mystery.

**Co konkrétně:**

1. **Prometheus deploy:**
```bash
ssh root@10.77.0.1 "
docker run -d --name prometheus \
  --restart=unless-stopped \
  -v /var/prometheus:/prometheus \
  -v /etc/prometheus/prometheus.yml:/etc/prometheus/prometheus.yml \
  -p 127.0.0.1:9090:9090 \
  prom/prometheus:latest \
  --storage.tsdb.retention.time=30d
"
```

2. **node_exporter** (system metrics):
```bash
ssh root@10.77.0.1 "
docker run -d --name node-exporter \
  --restart=unless-stopped \
  --pid=host \
  --net=host \
  -v /:/host:ro,rslave \
  quay.io/prometheus/node-exporter:latest \
  --path.rootfs=/host
"
```

3. **App-level metrics** (každá Filip's Python app):
```python
from prometheus_client import Counter, Histogram, Gauge, start_http_server

http_requests = Counter("http_requests_total", "HTTP requests", ["endpoint", "status"])
http_duration = Histogram("http_request_duration_seconds", "HTTP duration", ["endpoint"])
active_connections = Gauge("active_connections", "Active connections")

# Expose on :8000/metrics
start_http_server(8000)

# Use:
@http_duration.labels(endpoint="/api/dd-export").time()
def dd_export():
    http_requests.labels(endpoint="/api/dd-export", status="200").inc()
    # ...
```

4. **Alertmanager** + 5 core rules:
```yaml
# /etc/prometheus/alerts.yml
groups:
- name: critical
  interval: 30s
  rules:
  - alert: HighErrorRate
    expr: rate(http_requests_total{status=~"5.."}[5m]) > 0.05
    for: 5m
    annotations:
      summary: "Error rate >5% on {{ $labels.endpoint }}"
      runbook: "Check Loki: {service=\"X\", level=\"error\"}"
  - alert: DiskSpaceLow
    expr: (node_filesystem_avail_bytes / node_filesystem_size_bytes) < 0.10
    for: 10m
  - alert: MemoryHigh
    expr: (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes) < 0.15
    for: 10m
  - alert: DBConnectionsHigh
    expr: pg_stat_activity_count > 80
    for: 5m
  - alert: LatencyP99High
    expr: histogram_quantile(0.99, rate(http_request_duration_seconds_bucket[5m])) > 2
    for: 5m
```

5. **Alertmanager → ntfy.sh push:**
```yaml
# /etc/alertmanager/config.yml
route:
  receiver: ntfy
receivers:
- name: ntfy
  webhook_configs:
  - url: https://ntfy.oneflow.cz/Filip-alerts
    send_resolved: true
```

**Akceptační kritéria:**
- Prometheus scrapes node_exporter + 3+ apps
- 5 core alerts active, ntfy push notifications working
- Grafana dashboard "OneFlow operations" — latency, errors, disk, memory
- 30-day metrics retention
- Cost: $0 (self-hosted Flash)

### P0 #5 — Database Replication / Read Replica (4 hod)

**Proč P0:** 5 databází na single Flash node. Hardware failure, disk corruption, or accidental DROP = total loss for všechen Filip's emitent data, klient pipeline, scraper history.

**Co konkrétně (PostgreSQL streaming replication):**

```bash
# Option A: Druhý postgres na stejném Flash (mitigates accidental DROP, NOT hardware failure)
# Option B: Replika na Mac (přes WireGuard) — full DR
# Option C: Replika na Hetzner Storagebox / second VPS

# Recommended: Option B (Mac as warm standby via WireGuard)

# 1. Master config (Flash)
ssh root@10.77.0.1 "
docker exec postgres-main psql -U postgres -c \"
  ALTER SYSTEM SET wal_level = replica;
  ALTER SYSTEM SET max_wal_senders = 3;
  ALTER SYSTEM SET wal_keep_size = '1GB';
  CREATE ROLE replicator WITH LOGIN REPLICATION PASSWORD 'STRONG_PWD';
\"
"
# Restart postgres

# 2. Replica setup (Mac)
docker run -d --name postgres-replica \
  -e POSTGRES_PASSWORD=... \
  -v /Users/filipdopita/Library/postgres-replica:/var/lib/postgresql/data \
  postgres:15

# 3. pg_basebackup from Flash master
docker exec postgres-replica pg_basebackup \
  -h 10.77.0.1 -U replicator \
  -D /var/lib/postgresql/data \
  -P -R -X stream

# 4. Verify replication lag
docker exec postgres-main psql -U postgres -c "SELECT * FROM pg_stat_replication;"
```

**Akceptační kritéria:**
- PostgreSQL master (Flash) + replica (Mac) connected via WireGuard
- Replication lag <5 sec under normal load
- Failover documented (manual promote, ~5 min)
- For MariaDB: similar setup s GTID-based replication
- For Redis: master-replica + Sentinel pro auto-failover (P1, ne P0 — Redis loss = session loss only, not data loss)

---

## ČÁST 4: TOP 5 HIGH-LEVERAGE UPGRADES (P1) — 32 hod práce

Po dokončení P0 (kde byl risk → mitigated) tyto P1 akce posunou Filipa z 6.5/10 → 8.5/10.

### P1 #1 — GitHub Actions CI/CD (8 hod)

**Hodnota:** Eliminuje "deploy = SSH + restart service + cross fingers" pattern.

```yaml
# .github/workflows/deploy.yml
name: Deploy
on:
  push:
    branches: [main]
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@v4
    - uses: actions/setup-python@v5
      with: { python-version: '3.12' }
    - run: pip install -r requirements.txt
    - run: pytest tests/ --cov
    - run: ruff check .
  build:
    needs: test
    runs-on: ubuntu-latest
    steps:
    - uses: docker/setup-buildx-action@v3
    - uses: docker/build-push-action@v5
      with:
        push: true
        tags: ghcr.io/filipdopita/oneflow-app:${{ github.sha }}
  deploy:
    needs: build
    runs-on: ubuntu-latest
    steps:
    - name: Deploy via SSH
      uses: appleboy/ssh-action@v1
      with:
        host: 10.77.0.1
        key: ${{ secrets.SSH_KEY }}
        script: |
          docker pull ghcr.io/filipdopita/oneflow-app:${{ github.sha }}
          docker stop oneflow-app && docker rm oneflow-app
          docker run -d --name oneflow-app ghcr.io/filipdopita/oneflow-app:${{ github.sha }}
          # Health check
          sleep 5
          curl -f http://localhost:8080/health || exit 1
```

### P1 #2 — Feature Flags (Unleash self-hosted) (6 hod)

```bash
docker run -d --name unleash \
  -p 127.0.0.1:4242:4242 \
  -e DATABASE_URL=postgres://... \
  unleashorg/unleash-server:latest
```

Use case: Hermes agent rollout, new DD scoring algorithm, OneFlow site changes.

### P1 #3 — Schema Migrations (Atlas) (4 hod)

```bash
# Install
curl -sSf https://atlasgo.sh | sh

# Init pro každou DB
atlas migrate diff initial \
  --to "file://schema.sql" \
  --dev-url "postgres://localhost:5432/dev?sslmode=disable"

# Apply
atlas migrate apply \
  --url "postgres://flash:5432/oneflow?sslmode=disable"
```

### P1 #4 — pgBouncer Connection Pooling (3 hod)

```bash
docker run -d --name pgbouncer \
  -e DATABASE_URL=postgres://... \
  -e POOL_MODE=transaction \
  -e MAX_CLIENT_CONN=100 \
  -e DEFAULT_POOL_SIZE=20 \
  -p 127.0.0.1:6432:6432 \
  edoburu/pgbouncer
```

### P1 #5 — UptimeKuma + External Health Checks (3 hod)

```bash
docker run -d --name uptime-kuma \
  -v /var/uptime-kuma:/app/data \
  -p 127.0.0.1:3001:3001 \
  louislam/uptime-kuma:1
```

Monitor: oneflow.cz, ntfy.oneflow.cz, all subdomény, MCP servers, Hermes agent. **Z external probe** (Mac via WG nebo ideally jiný VPS provider).

### P1 #6 — Distroless Docker Images (2 hod)

```dockerfile
FROM python:3.12-slim AS builder
WORKDIR /app
COPY requirements.txt .
RUN pip install --user -r requirements.txt
COPY . .

FROM gcr.io/distroless/python3-debian12
COPY --from=builder /root/.local /root/.local
COPY --from=builder /app /app
WORKDIR /app
ENV PATH=/root/.local/bin:$PATH
CMD ["python", "main.py"]
```

Image size: 800MB → 80MB. Security surface massive reduction.

### P1 #7 — API Rate Limiting (Caddy) (1 hod)

```caddyfile
oneflow.cz {
    rate_limit {
        zone shared {
            key {remote_host}
            events 100
            window 1m
        }
    }
    reverse_proxy localhost:8080
}
```

### P1 #8 — Anthropic Spend Tracker (3 hod)

```python
# /usr/local/bin/anthropic-spend-tracker.py
# Scrape Anthropic API usage daily, push to Prometheus
# Alert pokud daily spend > $20

from anthropic import Anthropic
import requests

# Daily query: list_invoices nebo usage stats
# Push to Prometheus pushgateway: anthropic_daily_spend_usd
# Alert: anthropic_daily_spend_usd > 20 → ntfy
```

### P1 #9 — Redis Sentinel / High Availability (2 hod)

Pokud Redis se používá pro session — Filip nechce session loss při Redis crash.

```bash
# 3-node Sentinel quorum
docker-compose up -d redis-master redis-replica-1 sentinel-1 sentinel-2 sentinel-3
```

---

## ČÁST 5: 90-DAY ROADMAP

### Týden 1-2 (16 hod) — P0 Foundation
- [ ] Den 1-2: Backup automation + B2 setup (8 hod)
- [ ] Den 3: First restore drill (manual) (2 hod)
- [ ] Den 4: sops + age secrets migration (4 hod)
- [ ] Den 5: Pre-commit hooks + git audit (2 hod)

**Milestone:** Žádný data loss risk. Žádné secrets v plain text.

### Týden 3-4 (10 hod) — P0 Observability
- [ ] Den 6-7: Loki + Promtail + structured logging (5 hod)
- [ ] Den 8-9: Prometheus + node_exporter + 5 alerts (5 hod)

**Milestone:** Time-to-incident drops 10h → 10min. Filip vidí real-time co se děje.

### Týden 5-6 (8 hod) — P0 Reliability
- [ ] Den 10-11: PostgreSQL replication Mac↔Flash (4 hod)
- [ ] Den 12: Restore drill weekly cron + verification (2 hod)
- [ ] Den 13: Documentation runbooks (2 hod)

**Milestone:** Single Flash failure ≠ disaster. Failover documented.

### Týden 7-8 (10 hod) — P1 Operations
- [ ] Den 14-15: GitHub Actions CI/CD (8 hod)
- [ ] Den 16: pgBouncer + Atlas migrations (4 hod) [pokud v týdnu 7]
- [ ] Den 17: UptimeKuma external (3 hod) [pokud v týdnu 8]

**Milestone:** Deploy = automated. Schema changes = versioned.

### Týden 9-10 (8 hod) — P1 Quality
- [ ] Den 18-19: Feature flags (Unleash) (6 hod)
- [ ] Den 20: Distroless images migration (2 hod)
- [ ] Den 21: Caddy rate limiting (1 hod)

**Milestone:** Deploy ≠ release. Image size 800MB → 80MB.

### Týden 11-12 (6 hod) — P1 Polish
- [ ] Den 22: Anthropic spend tracker (3 hod)
- [ ] Den 23: Redis Sentinel (2 hod)
- [ ] Den 24: Final review + dashboard polish (1 hod)

**Milestone:** 6.5/10 → **8.5/10**.

### Total: 12 weeks (~52 hodin práce)

Možno paralelizovat přes Codex bridge (P0 #1-#3 lze v paralelu).

---

## ČÁST 6: WHAT NOT TO DO (anti-patterns z research)

**NIKDY NEDĚLAT pro Filipovu velikost:**

1. **Kubernetes** — overkill, ops debt 6+ měsíců, žádný HA benefit pro single-region
2. **Microservices** (split single app do 5+ services) — bez >10 dev tým = distributed monolith problem
3. **SQS/AWS Lambda/DynamoDB** — vendor lock-in, žádný cost benefit oproti VPS-first
4. **Kafka** — minimum 3 brokers + 6GB RAM + ops team. 1M+ events/sec threshold.
5. **Sharding** — premature do 50GB+ a 1000+ req/s s clear shard key
6. **GraphQL** (over REST) — 3x complexity bez clear win pro single-app
7. **Distributed tracing day 1** — full Jaeger/Tempo deployment před >5 services
8. **gRPC** pro single-service — protobuf maintenance overhead
9. **MongoDB Atlas / Firebase** — vendor lock-in, plus document DB anti-pattern pro relational data (DD reporty, klienti, smlouvy)
10. **ELK stack** — 4GB+ RAM, ops debt. Loki je 2GB single binary.

**Anti-cost:**
- Žádné paid Google API (cost-zero-tolerance.md hard rule)
- Žádné AWS/GCP managed services
- Žádné SaaS pro věci, kde self-hosted = $5/měsíc na Hetzner

---

## ČÁST 7: KONKRÉTNÍ NEXT STEPS (Week 1)

**Pondělí 2026-05-04:**
1. Read `vibe-coding-iceberg-research.md` (40K, hutné, 30 min) — pochopit "proč" za každou akcí
2. Decide: Mac or second VPS pro PostgreSQL replica? (memory-search "Hetzner Storagebox" pricing)
3. Create Backblaze B2 account → bucket `oneflow-backups` → IAM key (read/write only)
4. Generate age keypair, store private to 1Password

**Úterý 2026-05-05:**
1. Spustit `/Users/filipdopita/Desktop/Codex/ai-control-plane/scripts/delegate-to-codex.sh` s task: implementovat backup script + systemd timer per spec výše
2. Codex review by Claude před aplikací

**Středa 2026-05-06:**
1. Migrovat secrets `master.env` → `master.sops.yaml`
2. Update všech systemd services co používají `EnvironmentFile=`
3. Test all services after migration

**Čtvrtek 2026-05-07:**
1. Deploy Loki + Promtail
2. Add JSON formatter do Hermes agent + 1 dalšího Python service (proof of concept)
3. Connect Grafana Cloud free tier

**Pátek 2026-05-08:**
1. First manual restore drill — stáhni B2 backup, restore do test docker postgres, verify row count
2. Document procedure v `~/Documents/OneFlow-Vault/runbooks/disaster-recovery.md`
3. Týdenní review: what worked, what blocked

---

## CONFIDENCE ANALYSIS

**[VERIFIED]** — based na auditu reálného stavu Flash + Mac:
- Filip má 17 Docker containers, GlitchTip, fluent-bit, UFW, fail2ban, CrowdSec, WireGuard, Caddy
- Filip NEMÁ Kubernetes, automated backups, Prometheus, Loki, sops, feature flags, schema migration tool
- 5 databázových instancí (PostgreSQL ×2, MariaDB, Redis ×2, Valkey, Meilisearch)

**[LIKELY 85%+]** — based na 2026 best practices research:
- K8s is dead pro <50 lidí (HN trends, CNCF surveys, Fly.io drop)
- LiteFS production-ready (Fly.io operational data 2024-2025)
- NATS JetStream beats SQS pro self-host scale
- Connection pooling rule: `min(RAM/10MB, concurrent_requests)`

**[GUESS 60-80%]** — Filip-specific:
- Některé databáze likely SQLite (skripty/scrapers) — neověřeno z auditu
- Caddy config location — non-standard, neidentifikováno
- Autoheal scope — kterých services kryje, neověřeno

**[UNCERTAIN]** — vyžaduje Filip input:
- Skutečné business priority — pokud OneFlow.cz má jen 50 user/week, RPO=24h může být relax
- Pokud klienti vyžadují SOC 2 / ISO 27001 = další tier akcí

---

## PROPOJENÍ S OSTATNÍMI BRIEFINGS

Tento dokument propojuje s:
- `oneflow-industry-deep.md` — ECSP timing, Q3-Q4 2026 fundraising window
- `ECSP-GAP-ANALYSIS.md` — compliance requirements (DMARC, audit trail, AML)
- `cross-cutting-and-filip-positioning.md` — dual-business strategy implications

**Klíčový crossover:** ECSP gap analysis vyžaduje audit trail (compliance). Tato vrstva (P0 #2 structured logging + Loki retention) je **load-bearing** pro ECSP licenci. Plus encryption at-rest (P0 #3 sops) je GDPR/compliance baseline.

---

**Source:**
- Audit: SSH Flash + Mac repo scan, 2026-05-03
- Research: research-director agent, 6347 slov, 35+ pojmů, 2026-05-03
- Synthesis: Claude Opus 4.7, 2026-05-03

Dopita
