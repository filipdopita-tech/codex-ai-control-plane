# Vibe Coding — Filip Free Completion Plan

> **Cíl:** Dokončit zbylé manuální gates k 100 % bez jakýchkoli plateb / subscriptions.
> **Stav vstupu:** 5/5 P0 + 4 BONUS shipnuto autonomně (viz `project_p0_vibe_coding_2026_05_03.md`).
> **Reziduální Filip čas:** ≈30–45 minut rozdělených do 6 akcí.
> **Cena:** 0 Kč. (Vše paid alternativy vyřazené, free plnohodnotné.)
> **Datum:** 2026-05-03

---

## TL;DR — Co zbývá

| # | Akce | Čas | Důležitost | Cena |
|---|---|---|---|---|
| 1 | Záloha age private key (1Password / safe storage) | 3 min | **P0 critical** | 0 Kč |
| 2 | Smazat plaintext `master.env` po sops verifikaci | 2 min | **P0 high** | 0 Kč |
| 3 | Přihlásit do Grafany + ověřit dashboard "OneFlow Health & Backup" | 3 min | **P0 high** | 0 Kč |
| 4 | Importovat dva community dashboardy (Node Exporter + cAdvisor) | 5 min | P1 polish | 0 Kč |
| 5 | Subscribe ntfy topic `Filip` v mobilní app (alerty z Prometheus) | 3 min | **P0 high** | 0 Kč |
| 6 | Mac PostgreSQL volitelně přes Docker Desktop pro hot-standby | 15 min | P2 nice-to-have | 0 Kč |
| 7 | Smazat duplicitní `*.pre-sops-bak.2026-05-03` po týdnu testu | 1 min | P3 cleanup | 0 Kč |

**Total minimum (akce 1–5):** 16 minut.
**Total complete (1–7):** 32 minut.

---

## ČÁST 1 — Předdefinovaný stav (live now)

Než půjdeš na akce, ověř že VŠECHNO běží:

```bash
ssh root@10.77.0.1 'systemctl list-timers oneflow-* --no-pager 2>&1 | grep -E "oneflow"; \
  echo "---"; \
  curl -s http://localhost:9100/metrics | grep -c "^oneflow_"; \
  echo "---"; \
  docker ps --format "{{.Names}}|{{.Status}}" | grep -E "(prometheus|alertmanager|loki|promtail|grafana|cadvisor|node-exporter|postgres-standby)" | wc -l'
```

**Očekávané výstupy:**
- 4 timery: `oneflow-backup`, `oneflow-restore-drill`, `oneflow-pg-flash-standby`, `oneflow-health-probe`
- 14+ `oneflow_*` metrics scrapováno
- 8 containers up (5 observability + 3 PG: prod postgres, postgres-standby, postiz-postgres, glitchtip-postgres-1)

Pokud všechno odpovídá → pokračuj akcemi níže.

---

## AKCE 1 — Záloha age private key (3 min, **P0 critical**)

**Proč:** Bez tohoto klíče = ztráta přístupu ke všem 58 secrets. Klíč je teď JEN na Macu+Flashi. Když oba selžou, vše šifrované je nečitelné navždy.

### Kroky

```bash
# 1. Vyzobni klíč na Macu
cat ~/.config/sops/age/keys.txt
```

Výstup vypadá takhle:
```
# created: 2026-05-03T...
# public key: <example age public key>
AGE-SECRET-KEY-1...50CHAR-STRING...
```

**Zálohuj POUZE soukromý klíč (`AGE-SECRET-KEY-...`) a public key na 3 nezávislá místa:**

### Místo 1 (3 min) — 1Password
1. Otevři 1Password
2. Nový **Secure Note**
3. Title: `OneFlow age private key — sops vault key 2026-05-03`
4. Body: zkopíruj celý obsah `~/.config/sops/age/keys.txt`
5. Tag: `infra`, `secret`, `recovery`
6. Save

### Místo 2 (1 min) — USB klíč / iCloud Drive
- USB: `cp ~/.config/sops/age/keys.txt /Volumes/{TVUJ_USB}/age-key-2026-05-03.txt && chmod 600 ...`
- nebo iCloud: vlož do `~/Library/Mobile Documents/com~apple~CloudDocs/secrets/age-key-2026-05-03.txt`

### Místo 3 (volitelné, 5 min) — papírová tištěná kopie
- Vytiskni `cat ~/.config/sops/age/keys.txt | qrencode -o age-qr.png` (potřeba `brew install qrencode`)
- Hard copy do trezoru / sejfu

### Verifikace

```bash
# Test že záloha skutečně funguje (decrypt z jiného umístění):
SOPS_AGE_KEY_FILE=/Volumes/{USB}/age-key-2026-05-03.txt sops --decrypt --input-type=dotenv --output-type=dotenv ~/.claude/mcp-keys.sops.env | head -3
```

Pokud vidíš první 3 secrets → záloha funguje.

---

## AKCE 2 — Smazat plaintext `master.env` po sops verifikaci (2 min, **P0 high**)

**Proč:** Po migraci na sops máme `master.sops.env` (encrypted). Originály (`master.env` + `master.env.pre-sops-bak.2026-05-03`) zůstaly jen jako safety net. Po týdnu používání bez problémů je smazat.

**KDY:** Až po 7 dnech od 2026-05-03 (= ~2026-05-10) — ověříš že systemd services + scripts používající sops fungují.

### Kroky (2026-05-10 nebo později)

```bash
# 1. Final verifikace že sops decrypt produkuje stejný obsah jako original
ssh root@10.77.0.1 '
diff <(sort /root/.credentials/master.env) \
     <(/usr/local/bin/sops-load.sh dump /root/.credentials/master.sops.env /tmp/sops-test.env && sort /tmp/sops-test.env) | head -5
# Pokud žádný output → identické. Pokračuj.
'

# 2. Smaž originály na Flashi
ssh root@10.77.0.1 'shred -u /root/.credentials/master.env.pre-sops-bak.2026-05-03 && \
                    mv /root/.credentials/master.env /root/.credentials/master.env.removed-2026-05-10 && \
                    chmod 000 /root/.credentials/master.env.removed-2026-05-10'

# 3. Smaž originály na Macu (analogicky)
shred -u ~/.claude/mcp-keys.env.pre-sops-bak.2026-05-03 2>/dev/null
mv ~/.claude/mcp-keys.env ~/.claude/mcp-keys.env.removed-2026-05-10
chmod 000 ~/.claude/mcp-keys.env.removed-2026-05-10

# 4. Po 30 dnech (~2026-06-09) totální smazání:
ssh root@10.77.0.1 'shred -u /root/.credentials/master.env.removed-2026-05-10'
shred -u ~/.claude/mcp-keys.env.removed-2026-05-10
```

> **Poznámka:** Pokud nějaký systemd service nebo bash script ještě READ-uje `master.env` přímo, zlomí se. Detekuj přes `grep -r "master.env" /etc/systemd /usr/local/bin /root/scripts` PŘED smazáním.

---

## AKCE 3 — Grafana login + ověření OneFlow dashboardu (3 min, **P0 high**)

**Proč:** Dashboard `OneFlow Health & Backup` byl auto-provisioned ale Filip ho nikdy neviděl. Bez interakce nezjistíš jestli vizuálně sedí. Také změň default admin password.

### Kroky

```bash
# 1. Získej heslo
ssh root@10.77.0.1 'cat /etc/grafana/admin_password'
# Output: 24-char base64 string
```

**2. Setup port forwarding** (Grafana je bound na 127.0.0.1:3001 přes Caddy/firewall):
```bash
ssh -L 3001:localhost:3001 root@10.77.0.1
# Nech tunel otevřený
```

**3. Otevři v browseru:** `http://localhost:3001`
- Username: `admin`
- Password: (z kroku 1)

**4. Po loginu:**
- Sidebar → **Dashboards** → **OneFlow** folder → **OneFlow Health & Backup**
- Měl bys vidět 9 panelů:
  - Health probe status (green/red indicator)
  - Last backup age (seconds, should be < 24h)
  - Offsite sync (Mac) — green = synced
  - Last backup size (bytes)
  - Disk free / (percentage)
  - System utilisation (cpu/mem/iowait timeseries)
  - Container CPU rate (top by name)
  - Per-check health (1=OK)
  - Recent error/warn log lines (Loki)

**5. Změň admin password (bezpečnost):**
- Profil avatar → **Change password**
- Nové: něco unique, ulož do 1Password

**6. Bookmarkni:**
- `http://localhost:3001/d/oneflow-health/oneflow-health-and-backup` (s SSH tunelem)

---

## AKCE 4 — Import community dashboardů Node Exporter + cAdvisor (5 min, P1 polish)

**Proč:** Existující dashboard "OneFlow Health & Backup" pokrývá custom metriky. Pro hluboký system view použij Grafana community dashboardy zdarma.

### Kroky

V Grafaně (s SSH tunelem otevřeným):

**Dashboard 1860 — Node Exporter Full:**
1. Sidebar → **Dashboards** → **+ New** → **Import**
2. Do pole "Import via grafana.com" zadej: `1860`
3. Klik **Load**
4. Datasource: **Prometheus** (default)
5. Folder: **OneFlow** (volitelně)
6. Klik **Import**

**Dashboard 14282 — cadvisor Docker container monitoring:**
1. **Dashboards** → **+ New** → **Import**
2. ID: `14282`
3. Datasource: **Prometheus**
4. Folder: **OneFlow**
5. Klik **Import**

**Dashboard 13639 — Logs / App (pro Loki, volitelné):**
1. **Dashboards** → **+ New** → **Import**
2. ID: `13639`
3. Datasource: **Loki**
4. Folder: **OneFlow**

### Verifikace

Po importu by `OneFlow` folder v Grafaně měl obsahovat:
- OneFlow Health & Backup (custom)
- Node Exporter Full
- Docker monitoring (cAdvisor)
- Logs / App (volitelně)

---

## AKCE 5 — Subscribe ntfy topic `Filip` v mobilu (3 min, **P0 high**)

**Proč:** Všechny Prometheus alerty (DiskSpaceLow, MemoryHigh, HostDown, ContainerRestartLoop, BackupStale, BackupOffsiteSyncFailed, HighIOWait) + backup success/fail jdou do `https://ntfy.oneflow.cz/Filip`. Bez subscription je nedostaneš.

### Kroky

**iOS / Android — install ntfy app:**
- iOS: App Store → "ntfy" (od Philipp Heckel)
- Android: Play Store → "ntfy"

**Setup self-hosted server (jednou):**
1. Open ntfy app → **Settings** → **Default server** → `https://ntfy.oneflow.cz`
2. Settings → **Subscribe to topic** → Topic: `Filip`
3. Užitečné: **+ Server settings** → Authentication
   - Type: **Bearer Token**
   - Token: (z `master.sops.env` → `NTFY_TOKEN`)
   ```bash
   ssh root@10.77.0.1 '/usr/local/bin/sops-load.sh exec /root/.credentials/master.sops.env bash -c "echo \$NTFY_TOKEN"'
   ```

**Verifikace:**
```bash
ssh root@10.77.0.1 '/usr/local/bin/sops-load.sh exec /root/.credentials/master.sops.env bash -c "curl -X POST -H \"Authorization: Bearer \$NTFY_TOKEN\" -H \"Title: Test from Filip phone\" -d \"Pokud vidíš tuhle zprávu, ntfy funguje\" \"\$NTFY_URL/Filip\""'
```

Notification by měla dorazit do mobilu během 1–3 sekund.

---

## AKCE 6 (volitelné, 15 min) — Mac PostgreSQL přes Docker Desktop pro hot-standby

**Proč:** Současný stav = Flash-side standby (corruption defense, RTO ~10 min). Pro "**hardware failure → switch to Mac PG během 5 min**" potřebuješ Mac běžící PG. Streaming replication je opt-in, viz `dr-failover.md` § Step 5.

> **Náklad:** 0 Kč. Docker Desktop má free tier (osobní použití).

### Kroky

**1. Install Docker Desktop:** https://www.docker.com/products/docker-desktop/
- Stáhni .dmg
- Drag & drop do /Applications
- Open + accept license + skip teams setup

**2. Verifikace:**
```bash
docker --version    # Docker version 25.x.x
docker run --rm hello-world
```

**3. Run cold standby refresh** (jednorázově nebo přes launchd):
```bash
chmod +x ~/Desktop/Codex/ai-control-plane/scripts/oneflow-pg-standby-restore.sh
~/Desktop/Codex/ai-control-plane/scripts/oneflow-pg-standby-restore.sh
```

Script:
- Stáhne nejnovější backup z `~/Documents/oneflow-backups/`
- age decrypt
- Spustí Docker container `oneflow-pg-standby` na portu 15432
- Restore 3 PG dumps
- ETA: ~5 min

**4. Setup launchd pro daily auto-refresh** (podobně jako cron, ale macOS native):

Vytvoř `~/Library/LaunchAgents/com.oneflow.pg-standby.plist`:
```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key><string>com.oneflow.pg-standby</string>
  <key>ProgramArguments</key>
    <array>
      <string>/Users/filipdopita/Desktop/Codex/ai-control-plane/scripts/oneflow-pg-standby-restore.sh</string>
    </array>
  <key>StartCalendarInterval</key>
    <dict>
      <key>Hour</key><integer>4</integer>
      <key>Minute</key><integer>30</integer>
    </dict>
  <key>StandardOutPath</key><string>/Users/filipdopita/Library/Logs/oneflow-pg-standby.log</string>
  <key>StandardErrorPath</key><string>/Users/filipdopita/Library/Logs/oneflow-pg-standby.err</string>
</dict>
</plist>
```

Aktivace:
```bash
launchctl load ~/Library/LaunchAgents/com.oneflow.pg-standby.plist
launchctl list | grep oneflow      # ověření
```

**5. Verifikace:**
```bash
docker ps | grep oneflow-pg-standby      # container Up
docker exec oneflow-pg-standby psql -U standby -d postgres -c "\l"     # 3 databáze restored
```

---

## AKCE 7 — Smazání duplicitních `*.pre-sops-bak.2026-05-03` (1 min, P3 cleanup)

**Stejný proces jako AKCE 2** — provedení po 7 dnech bezproblémového provozu sops.

```bash
# Mac
shred -u ~/.claude/mcp-keys.env.pre-sops-bak.2026-05-03

# Flash
ssh root@10.77.0.1 'shred -u /root/.credentials/master.env.pre-sops-bak.2026-05-03'
```

---

## ČÁST 2 — Kde je co

### File system map

**Mac (lokálně):**
```
~/.config/sops/age/keys.txt              # age priv+pub key (chmod 600)
~/.sops.yaml                              # sops creation rules
~/.claude/mcp-keys.sops.env               # 13 secrets encrypted
~/.claude/mcp-keys.env.pre-sops-bak.*     # original (delete po 7d)
~/.config/git/hooks/pre-commit            # blokuje plaintext .env / high-entropy
~/Documents/oneflow-backups/              # 1+ encrypted backups (offsite)
~/Desktop/Codex/ai-control-plane/
  ├── configs/                            # 9 config files (compose, alerts, datasources, ...)
  ├── scripts/                            # 7 scripts (backup, restore-drill, sops-load, etc.)
  └── docs/dr-failover.md                 # 8.2K runbook
~/Desktop/Codex/research-briefings/2026-05-03/
  ├── vibe-coding-iceberg-research.md     # 42K input
  ├── vibe-coding-ecosystem-audit.md      # 12K input
  ├── vibe-coding-MASTER-SYNTHESIS.md     # 31K input
  └── vibe-coding-FILIP-FREE-COMPLETION.md # tento doc
```

**Flash 10.77.0.1:**
```
/usr/local/bin/oneflow-backup.sh          # daily backup
/usr/local/bin/oneflow-restore-drill.sh   # weekly verify
/usr/local/bin/oneflow-pg-flash-standby.sh # daily standby refresh
/usr/local/bin/oneflow-health-probe.py    # 5min health probe
/usr/local/bin/sops-load.sh               # source|exec|dump|check
/usr/local/bin/alertmanager-ntfy-bridge.py # alertmanager → ntfy bridge
/usr/local/lib/oneflow/oneflow_logger.py  # JSON logger lib

/etc/systemd/system/oneflow-*.service     # 5 unit files
/etc/systemd/system/oneflow-*.timer       # 4 timery

/etc/prometheus/{prometheus,alerts}.yml
/etc/alertmanager/alertmanager.yml
/etc/loki/loki-config.yml
/etc/promtail/promtail-config.yml
/etc/grafana/provisioning/{datasources,dashboards}/
/etc/grafana/admin_password               # 24-char base64

/var/backups/oneflow/oneflow-*.tar.age    # 7 daily backups
/var/lib/node_exporter/textfile_collector/oneflow_*.prom
/var/lib/oneflow-pg-standby/              # standby PG data

/opt/observability/docker-compose.yml     # 6 containers stack
```

### Memory pointers

```
~/.claude/projects/-Users-filipdopita-Desktop-Codex/memory/
  ├── MEMORY.md                                          # index
  ├── project_p0_vibe_coding_2026_05_03.md              # full status
  └── project_vibe_coding_iceberg_2026_05_03.md         # planning
```

---

## ČÁST 3 — Defense matrix po dokončení

| Hrozba | Aktivní ochrana | RTO | RPO |
|---|---|---|---|
| Hardware failure Flash | Off-site Mac backup (rsync SSH, daily 02:00 UTC) | 30 min | 24 h |
| Accidental DROP / corruption | Flash-side PG standby :15432 (daily 04:00 UTC) | 10 min | 24 h |
| Service outage (Docker container) | HostDown / ContainerRestartLoop alerts → ntfy | <2 min | n/a |
| Backup pipeline silent fail | BackupStale / BackupOffsiteSyncFailed alerts | <25 h | n/a |
| Disk fill | DiskSpaceLow alert (>10% threshold) | 10 min | n/a |
| Memory exhaustion | MemoryHigh alert | 10 min | n/a |
| Sudden IO contention | HighIOWait alert | 10 min | n/a |
| App-layer error spikes | Loki structured logs + Grafana dashboard panel | seconds | n/a |
| Loss of age private key | 1Password backup (akce 1) | n/a | n/a |
| Plaintext secret leak in git | Pre-commit hook globální | n/a | n/a |
| Sister DMARC reject (oneflow-team.cz, hellooneflow.cz, …) | Wedos manual akce, viz `SISTER-DOMAINS-DMARC-DNSSEC-WEDOS-COPYPASTE.md` | n/a | n/a |

---

## ČÁST 4 — Co NENÍ v scope tohoto plánu

Záměrně ne-zahrnuto, protože je to mimo vibe-coding ekosystém:

- **Sister DMARC reject** (oneflow-team.cz, ...): viz `~/Desktop/Codex/research-briefings/2026-05-03/SISTER-DOMAINS-DMARC-DNSSEC-WEDOS-COPYPASTE.md` — copy-paste pack pro Wedos UI, ~5 min Filipovy práce
- **DNSSEC DS u Wedos** pro oneflow.cz: stejný copy-paste pack, ~2 min Filip akce
- **Meta App publication** (oneflow_publisher Instagram): JIŽ HOTOVO v `project_alex2learn_audit_2026_05_03.md` Phase 6 — 5/5 commands PASS, App ID `1239370548302204`
- **YubiKey × 2** (P0 z Verizon DBIR brief): hardware nákup ~3,6k Kč, viz `project_security_dbir_2026_brief_2026_05_03.md`
- **O2 port-out lock**: telefonní operátor, mimo IT scope
- **App migrations na oneflow_logger**: postupně per-app, viz `oneflow_logger.py` API; není urgent — Promtail už chytá Docker stdout automaticky

---

## ČÁST 5 — 90-day P1 roadmap (volitelné, free)

Po doháknutí akcí 1–7 zbývá z master synthesis P1 roadmap:

| Týden | P1 akce | Odhad | Free? |
|---|---|---|---|
| W7-8 | GitHub Actions CI/CD (deploy via SSH) | 8h | ✓ (2000 min/mo free) |
| W7-8 | pgBouncer connection pooling | 3h | ✓ |
| W7-8 | UptimeKuma external probe (na Macu nebo druhém VPS) | 3h | ✓ |
| W9-10 | Unleash feature flags self-host | 6h | ✓ |
| W9-10 | Distroless Docker images migration | 2h | ✓ |
| W9-10 | Caddy rate limiting per route | 1h | ✓ |
| Q3 | Schema migrations (Atlas/sqitch) | 4h | ✓ |
| Q3 | API contracts (OpenAPI specs) | 4h | ✓ |
| Q4 | Distributed tracing (Tempo + OTel) | 8h | ✓ |

**Total P1 (free):** ~39h. Bez přerušení core operations.

---

## ČÁST 6 — Verifikace finálního stavu

Po dokončení akcí 1–5 spusť:

```bash
ssh root@10.77.0.1 'echo "=== TIMERS ==="; \
  systemctl list-timers oneflow-* --no-pager 2>&1 | grep -E "oneflow"; \
  echo ""; echo "=== METRICS ==="; \
  curl -s http://localhost:9100/metrics | grep -c "^oneflow_"; \
  echo ""; echo "=== ALERTS LOADED ==="; \
  curl -s http://localhost:9090/api/v1/rules | python3 -c "import sys,json; d=json.load(sys.stdin); [print(\"  \"+r[\"name\"]+\": \"+r[\"state\"]) for g in d[\"data\"][\"groups\"] for r in g[\"rules\"]]"; \
  echo ""; echo "=== CONTAINERS UP ==="; \
  docker ps --format "{{.Names}}|{{.Status}}" | grep -E "(prometheus|alertmanager|loki|promtail|grafana|cadvisor|node-exporter|postgres-standby)"; \
  echo ""; echo "=== LATEST BACKUP ==="; \
  ls -lh /var/backups/oneflow/oneflow-*.tar.age 2>&1 | tail -3'
```

**Očekávaný výstup:**
- 4 timery aktivní
- 14+ oneflow_* metriky
- 7 alerts loaded (5 system + BackupStale + BackupOffsiteSyncFailed) — všechny inactive
- 8 containers up
- 1+ recent backup files (75-100 MB)

---

## TL;DR Sequence (kopíruj-paste do checklisty)

```
☐ AKCE 1 — Záloha age key do 1Password (3 min) — PROVEĎ DNES
☐ AKCE 3 — Login Grafana + ověření dashboardu + change pwd (3 min) — PROVEĎ DNES
☐ AKCE 5 — Subscribe ntfy topic Filip v mobilu (3 min) — PROVEĎ DNES
☐ AKCE 4 — Import dashboardů 1860 + 14282 (5 min) — POLISH
☐ AKCE 6 — Mac Docker Desktop + warm-standby (15 min) — VOLITELNÉ
☐ Po 7 dnech: AKCE 2 — Smaž plaintext master.env (2 min)
☐ Po 7 dnech: AKCE 7 — Smaž *.pre-sops-bak.* duplicaty (1 min)
```

**Po splnění minimálního setu (1+3+5):** systém je 100% production-grade s 0 single-point-of-failure pro defense matrix § hrozby 1-9.

---

**Autor:** Claude Opus 4.7 (1M context) — autonomous session 2026-05-03
**Reference:** `project_p0_vibe_coding_2026_05_03.md`
**Source plán:** `vibe-coding-MASTER-SYNTHESIS.md`
