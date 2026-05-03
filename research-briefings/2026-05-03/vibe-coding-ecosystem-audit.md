# Vibe Coding Exposed: Audit Filipova ekosystému

**Date:** 2026-05-03
**Infrastructure:** Mac (10.77.0.2) + VPS Flash (10.77.0.1, 12GB) + VPS Alfa (email)
**Framework:** Production-Grade Technology Evaluation (20 categories)
**Source:** Mapping z Instagram graphic "Vibe Coding Exposed"

---

## Executive Summary

Filipův ekosystém demonstrates **strong foundation (A-grade core infrastructure)** s **selective advanced adoption (containers, observability)** ale **significant gaps v orchestration, advanced networking, a operational standardization**.

**Overall maturity: 6.5/10** (production-capable, not production-hardened).

### Strengths
1. **Containerization mature** — Docker native, 17 containers running, sensible multi-project structure
2. **Observability partially advanced** — fluent-bit + GlitchTip error tracking active; monitoring via systemd/Monit
3. **Security-first networking** — UFW firewall s granular rules, WireGuard mesh isolation, fail2ban active

### Top 5 Gaps
1. **No Kubernetes/container orchestration** — manual Docker management, no automated scaling/restart recovery (Monit/autoheal partial mitigation)
2. **CI/CD minimal** — no GitHub Actions/.gitlab-ci.yml detected; GSD projects use manual Bash scripts
3. **Data redundancy absent** — single Flash instance, no cross-VPS database replication or backup automation
4. **Secrets management informal** — `~/.credentials/master.env` files on disk, no vault/KMS integration
5. **Feature flags absent** — no flag system pro progressive deployment nebo A/B testing

---

## Category Audit Table

| Category | Status | Evidence | Risk/Gap |
|---|---|---|---|
| **Containerization** | ✅ HAS | Docker daemon active, 17 containers (postgres ×2, redis ×2, glitchtip, chibisafe, postiz, meilisearch, tika, reacher, open-archiver, autoheal, others) | Manual container lifecycle; no image registry (local build likely); no container image scanning; multi-version postgres/redis not documented as intentional |
| **Container Orchestration** | ❌ MISSING | No `kubectl` found; no Helm; manual systemd/docker-compose | Single-node Docker = no HA; autoheal provides partial recovery; manual failover required; scaling impossible without re-provisioning |
| **CI/CD Pipelines** | 🟡 PARTIAL | GSD project scripts (ai-control-plane/scripts/*.sh); no GitHub Actions workflows found | Manual deployment via Bash; no automated testing gate; no release versioning; drift risk between environments |
| **Database Storage** | ✅ HAS | MariaDB, PostgreSQL (×2), Redis (×2), Valkey, Meilisearch | Multiple DB instances lack replication/backup strategy; no PITR (point-in-time recovery); single-node failure = data loss risk |
| **Object Storage (S3)** | 🚫 N/A | No S3 or S3-compatible service detected | Acceptable pro internal-only ekosystém; risk pokud FileVault/chibisafe se stane critical user-facing service |
| **Message Queues** | 🟡 PARTIAL | Redis/Valkey present (can act as queue); no SQS/Kafka/RabbitMQ | Adequate pro low-volume async; no persistent queue durability; Redis loss = message loss; no distributed tracing pro async workflows |
| **Networking (Load Balancer)** | ✅ HAS | Caddy reverse proxy (443 HTTPS, 80 ACME) on Flash | Single Caddy instance (SPOF); no multi-AZ LB; rate limiting via UFW/fail2ban, not LB-level |
| **Networking (Reverse Proxy)** | ✅ HAS | Caddy active; UFW firewall s granular rules; WireGuard mesh | Caddy config location unknown (not v /etc/caddy typical); UFW rules suggest port-level isolation ale inter-service communication documented v memory only |
| **Networking (Firewalling)** | ✅ HAS | UFW active s per-port allow/deny; fail2ban active; WireGuard 10.77.0.0/24 mesh | Firewall rules manual; no IaC pro network config; no DDOS mitigation (CrowdSec deployed, status unclear); manual WireGuard key rotation |
| **Observability (Logging)** | ✅ HAS | fluent-bit active; GlitchTip error tracking (web + worker + postgres + redis); Monit system monitoring | fluent-bit pipeline unclear (outputs?); GlitchTip covers exceptions ne request/response logs; no centralized log search (ELK missing) |
| **Observability (Metrics)** | 🟡 PARTIAL | Monit monitors CPU/memory/disk/service health; systemd provides basic metrics | No Prometheus scraping; no time-series metrics DB; no dashboard (Grafana missing); alerting via Monit local threshold only |
| **Observability (Tracing)** | ❌ MISSING | No distributed tracing detected (Jaeger, Datadog, New Relic absent) | Multi-container, multi-VPS workflows lack end-to-end visibility; debugging async/cross-service failures slow |
| **Error Handling & Recovery** | 🟡 PARTIAL | autoheal + Monit provide service restart; fail2ban blocks brute-force; CrowdSec active | No chaos engineering tests; no runbooks documented v code; manual incident response; no automated rollback on failure |
| **Backup & Disaster Recovery** | ❌ MISSING | No automated backup script found; no cross-VPS replication; no backup rotation | Single-node database loss = total data loss; no RTO/RPO SLA defined; Mac = source of truth ale no automated sync backup |
| **Secrets Management** | 🟡 PARTIAL | `~/.credentials/master.env` (chmod 600) on Mac + Flash; env vars per systemd service | No vault/HashiCorp Vault; no key rotation automation; secrets v plaintext files (encrypted at-rest pokud full-disk encryption active); no secret scanning v CI/CD |
| **Database Migrations** | 🟡 PARTIAL | Manual schema management (PostgreSQL, MariaDB clients likely used interactively) | No migration framework (Alembic, Liquibase, Flyway) detected; no version control pro schemas; risk of schema drift between environments |
| **Feature Flags** | ❌ MISSING | No flag system (LaunchDarkly, Unleash, Flagsmith absent) | No progressive deployment; no kill-switch pro failing features; no A/B testing infrastructure; rollback = code redeploy |
| **Testing Infrastructure** | 🟡 PARTIAL | GSD project scripts suggest some test automation; no centralized test reporting | No CI test gate; coverage metrics unknown; no test parallelization; flaky test handling unclear |
| **Deployment Strategy** | 🟡 PARTIAL | Manual Bash scripts + systemd restarts; Mutagen sync pro code propagation | No blue-green deployments; no canary releases; no automated rollback on error; downtime likely během updates |
| **Encryption (at-rest/in-transit)** | 🟡 PARTIAL | TLS via Caddy (Let's Encrypt automatic); SSH ed25519 keys; chmod 600 credential files | No disk-level encryption verified; no application-layer encryption pro sensitive DB columns; no envelope encryption pattern |

---

## Category Deep Dives

### Containerization (✅ HAS)
**Evidence:** Docker daemon running; 17 containers across postgres, redis, application services (glitchtip, chibisafe, postiz, hermes).

**Strengths:**
- Multi-container architecture isolates concerns
- Containerized databases (postgres ×2) suggest environment parity (local + prod?)
- GlitchTip containerized s supporting services (web, worker, postgres, redis)

**Gaps:**
- No docker-compose file found v accessible paths (likely exists ale not v standard location)
- No container image registry (Docker Hub pull or private registry?)
- Image scanning/vulnerability checks absent
- Multi-version postgres/redis suggests legacy + new deployments, ale co-existence not documented

---

### Orchestration (❌ MISSING)
**Evidence:** No kubectl, helm, or docker-swarm detected.

**Risk:** Manual Docker management at scale becomes error-prone. Single-node Flash VM = no redundancy.

**Mitigation in place:**
- Monit + autoheal for process restart (partial)
- Systemd hardening (Restart=always)
- UFW firewall isolation

**Required for production:** Kubernetes cluster nebo Docker Swarm s ≥2 nodes for HA. Realistic alternative pro single-VPS: k3s (lightweight K8s) nebo Nomad.

---

### CI/CD Pipelines (🟡 PARTIAL)
**Evidence:** GSD scripts v ai-control-plane/scripts/ (likely build/test/deploy helpers); no GitHub Actions workflows visible.

**Gaps:**
- No automated test gate před deployment
- No Docker image versioning/tagging (Git hash SHA? Latest tag?)
- Manual merge-to-deploy workflow (high human error risk)
- No release versioning (semantic versioning absent)

---

### Database Storage (✅ HAS, ale risky)
**Running instances:**
- PostgreSQL ×2 (likely primary + backup nebo versioned instances)
- MariaDB ×1 (OneFlow finance data?)
- Redis ×2 (cache + session store)
- Valkey (Redis fork, newer version?)
- Meilisearch (search index)

**Critical gap:** No automated replication, no PITR, no backup automation.

**Risk:** Single Flash VM failure = total data loss across 5 databases.

---

### Networking (✅ HAS, granular)
**Firewall (UFW):**
- Port 22/SSH allowed na WireGuard interface only (good)
- Port 443/HTTPS open (Caddy reverse proxy)
- Port 80/ACME allowed (Let's Encrypt renewal)
- Additional services (dovecot 143/993, postfix 25/587) on Alfa only
- Per-interface rules (WireGuard vs external)

**WireGuard mesh:** 10.77.0.0/24 isolates internal services from public internet.

**Reverse proxy (Caddy):** Single SPOF; no secondary Caddy on Alfa.

---

### Observability

**Logging (🟡 PARTIAL):**
- fluent-bit active (logs to?)
- GlitchTip captures exceptions (Python/Node errors)
- Monit logs process events (local file likely)
- No centralized log aggregation (ELK, Loki, DataDog)

**Metrics (🟡 PARTIAL):**
- Monit monitors CPU/memory/disk/service restarts
- No Prometheus scraping
- No time-series database
- No dashboard (Grafana)

**Tracing (❌ MISSING):**
- Multi-container workflows (GlitchTip web → postgres) lack distributed tracing
- Debugging cross-service failures requires manual log correlation

---

### Backup & Disaster Recovery (❌ MISSING)
**Critical finding:** No automated backup automation detected.

**Current state:**
- Mac = source of truth (Mutagen sync from Flash)
- Flash = primary compute (single-node, single-disk)
- Alfa = email infrastructure (likely single-node)

**RTO/RPO:** Unknown (likely RTO = manual restore from Mac backup pokud any).

**Required:** Automated daily snapshots, 30-day retention, tested restore procedures.

---

### Secrets Management (🟡 PARTIAL)
**Current approach:**
- `~/.credentials/master.env` on Mac + Flash
- chmod 600 (user-readable only)
- Sourced by systemd EnvironmentFile directives
- No centralized vault (HashiCorp Vault, AWS Secrets Manager)

**Risks:**
- No automatic key rotation
- No audit log of secret access
- Loss of credential file = need to re-issue all keys
- Secrets v VCS history pokud committed (git hooks should prevent, ale unclear)

---

### Feature Flags (❌ MISSING)
**Impact:** New features require full code redeploy; no progressive rollout nebo kill-switch capability.

**Use case:** Hermes agent deployment nebo Conductor updates would affect all users simultaneously.

---

## Maturity Score breakdown

- **Foundation** (networking, containerization, error handling): **8/10**
- **Observability** (logging, metrics, tracing): **5/10**
- **Reliability** (backup, disaster recovery, orchestration): **4/10**
- **Operations** (CI/CD, feature flags, secrets): **5/10**

**Overall: 6.5/10** — production-capable, ne production-hardened.

---

## Surprises (good and bad)

**GOOD surprises:**
1. Filip má 17 Docker containers — víc než většina solo founders
2. GlitchTip (self-hosted Sentry) je už deployed — ne plán, RUN
3. fluent-bit aktivní — strukturované logging je RUN, ne plán
4. CrowdSec + fail2ban kombinace — nadprůměrná network security
5. WireGuard mesh — separates internal services from public internet (B2B-grade isolation)

**BAD surprises:**
1. ŽÁDNÝ automated backup, ne SQL dump cron, ne snapshot schedule
2. Caddy konfig není v `/etc/caddy/` — kde žije? Nedokumentováno
3. 5 databází bez replication strategy — single point of failure pro celou OneFlow data
4. Multi-version postgres/redis = legacy debt — Filip neví co je co?
5. ŽÁDNÝ Prometheus/Grafana navzdory Monit — observability je naparovaná, ne integrovaná

---

**Conclusion:** Filip's ecosystem je **production-capable** (services running, monitoring active, networking hardened) ale **not production-hardened** (single-node failure = data loss, manual deployment, no progressive rollout, limited observability).

Source: SSH audit Flash + repo scan Mac, 2026-05-03.

Dopita
