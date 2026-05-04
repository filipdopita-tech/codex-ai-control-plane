# OneFlow AI Ekosystém — Filip Dopita

> Solo-founder AI control plane: Mac (8GB) + 2× VPS + telefon + Obsidian, orchestrované přes Claude Code (orchestrator) a Codex (impl agent). **Single entry point: `ofs`**.
>
> **Snapshot 2026-05-04:** 292 skills · 96 agents · 69 hooks · 14 MCPs · WireGuard mesh · Mutagen sync · 20+ launchd/cron jobs.

---

## Pro kolegu — kde začít (5-min orientace)

1. **Architektura na jeden pohled:** [`ECOSYSTEM-DIAGRAM.md`](ECOSYSTEM-DIAGRAM.md) — ASCII layered view (harness → infra → knowledge → externí touchpoints).
2. **Operating manual pro Codex agenta:** [`AGENTS.md`](AGENTS.md) — 4 sacred rules + handoff contract + verify gate.
3. **Nejnovější closure (jak vypadá "hotová" wave):** [`AI-CONTROL-PLANE-CLOSURE-2026-05-04.md`](AI-CONTROL-PLANE-CLOSURE-2026-05-04.md).
4. **Patterns worth stealing** — viz sekce dole.
5. **Live entry point:** `ofs status` → 1 příkaz, full snapshot.

---

## TL;DR (denní použití)

```bash
ofs status            # full snapshot (Mac, VPS, sync, queue, CLIs)
ofs route "task"      # auto routing — lean Codex / full Codex / Claude review / strategy
ofs delegate "task"   # přímo do Codexu (impl v souborech)
ofs review "task"     # Claude review/risk gate
ofs verify <path>     # anti-halucinace gate (real git diff vs claims)
ofs mac               # Mac RAM/swap/CPU detail
ofs vps               # VPS Flash health
ofs handoffs          # poslední Codex/Claude handoffs (audit trail)
ofs logs              # ofs audit log
ofs help              # všechny commands
```

---

## Architektura

```
Filip
  ├─> Mac (8GB RAM, terminal + Claude Code)
  ├─> Telefon (Telegram dispatch — vyžaduje Hermes Agent up)
  └─> Browser → Obsidian dashboard (Vault-OS-Hub)
        │
        ▼
   `ofs` dispatcher (single entry point)
        │
   ai-control-plane router (route-task.sh)
        │
   ┌────┴───────────────────┐
 Codex CLI            Claude CLI
 (impl, repo)         (review, strategy, long context)
        │
   Mutagen + WireGuard + SSH
        │
   VPS Flash (12GB, 24/7, 10.77.0.1)
   ├ Conductor (file-based task queue + workers)
   ├ Hermes Agent (multi-platform gateway: Telegram/Discord/Slack/WA)
   ├ Paseo (agent UI, WG-only :6767)
   ├ Dovecot + Postfix (oneflow.cz mailbox)
   ├ Caddy + scrapers + ntfy.oneflow.cz
   ├ jobs-cz-system (reverse-recruiter scraper, daily 06:30)
   └ Cron heavy work + Prometheus/Grafana/Loki

   Alfa VPS (CZ IP relay, SMTP backup, Wedos legacy)
```

---

## 4 core mantras (immutable)

1. **Výsledek > Proces** — měřitelný outcome, ne plán
2. **0 halucinací** — verify-before-claim, `[VERIFIED]/[LIKELY]/[GUESS]/[UNCERTAIN]`
3. **Token efficiency** — VPS-first, model tier (Haiku → Sonnet → Opus)
4. **Security-first** — secrets v env files (sops+age), audit log, no RCE surface

---

## Komponenty (co kde běží)

### AI Control Plane (`ai-control-plane/scripts/`)

| Skript | Účel |
|---|---|
| `ofs.sh` | Single entry point dispatcher |
| `route-task.sh` | Sofistikovaný router se scoringem (auto / lean Codex / full Codex / Claude) |
| `delegate-to-codex.sh` | Claude → Codex bridge s verify gate (`AI_BRIDGE_VERIFY=0` to disable) |
| `ask-claude-review.sh` | Risk gate review (read-only) |
| `ask-claude-strategy.sh` | Strategy/architecture (no edit) |
| `verify-codex-result.sh` | Anti-halucinace — real `git diff` vs claimed changes |
| `resource-monitor.sh` | Mac+VPS+queue load (5min cron → JSONL) |
| `usage-tracker.sh` | Anthropic+OpenAI consumption (daily 09:00) |
| `obsidian-dashboard.sh` | Auto-update Ecosystem-Status.md (15min) |
| `security-audit.sh` | Weekly defense-in-depth scan (Sat 03:30) |
| `update-extended.sh` | MCP+Codex+npm+brew (manual nebo weekly) |
| `update-core.sh` | gcloud+brew+VS Code ext (Sat 04:15) |
| `doctor.sh` | Full diagnostic |
| `codex-bridge-smoke.sh` | Daily smoke test (launchd 10:15) |
| `mcp-process-audit.sh` | MCP runaway process detection |
| `cloudflare-publish-sister-dmarc.sh` | DMARC/SPF/DNSSEC ops pro 6 sister domén |

### Sub-projects (volitelné, samostatné READMEs)

| Path | Co to je |
|---|---|
| [`jobs-cz-system/`](jobs-cz-system/) | Reverse-recruiter pipeline. Scraper jobs.cz + prace.cz + StartupJobs → warm-signal scoring → leads.csv. Daily 06:30. |
| [`research-briefings/`](research-briefings/) | Strukturované deep-research briefy (industry, competitors, ecosystem audit). |
| `ai-control-plane/` | Plán, runbooky, recovery docs, optimization specs. |

### VPS-side komponenty (NE v repu, jen reference)

| Komponent | Lokace | Účel |
|---|---|---|
| Conductor | VPS `/opt/conductor/` | File-based task queue, free-LLM workers (OpenRouter) |
| Hermes Agent | VPS `/usr/local/bin/hermes` | Multi-platform gateway (Telegram/Discord/Slack/WA/Email) |
| Paseo | VPS `:6767` (WG-only) | Agent UI |
| jobs-cz-system | VPS `/root/jobs-cz/` | Live scraper (storage_state, Playwright) |
| Prometheus + Grafana + Loki | VPS | Observability stack (7 alerts, 9-panel dashboard) |
| Postfix + Dovecot | VPS Flash | dopita@oneflow.cz mailbox + SMTP relay |
| `health-probe` | VPS systemd timer | 7 health checks every 5 min → JSON → Loki |

---

## Cron / launchd schedule (Mac side)

| Job | Frequency | Purpose |
|---|---|---|
| `com.filipdopita.resource-monitor` | every 5 min | Mac+VPS metrics → JSONL |
| `com.filipdopita.obsidian-dashboard` | every 15 min | Auto-update vault dashboard |
| `com.filipdopita.usage-tracker` | daily 09:00 | Cross-provider usage summary |
| `com.filipdopita.claude-history-index` | hourly | Index Claude Code transcripts pro `/recall` |
| `com.oneflow.codex-bridge-smoke` | daily 10:15 | End-to-end Codex bridge smoke test |
| `com.oneflow.li-token-monitor` | daily | LinkedIn OAuth refresh status |
| `com.oneflow.daily-ekosystem-health` | daily | 7-dim health audit |
| `cz.oneflow.ai-radar-daily` | daily 03:35 | External tool radar + cross-ref |
| `cz.oneflow.ai-radar-weekly` | Mon 08:00 | Weekly deep-effort radar (top-10 falsification) |
| `cz.oneflow.weekly-retro` | Sun 09:00 | Eval + retro batch |
| `cz.oneflow.security-alert` | various | Security findings → ntfy |
| `com.oneflow.hibp-defensive-monitor` | monthly | Have-I-Been-Pwned own domains |
| `com.oneflow.huashu-design-update` | weekly | Design system templates refresh |
| `com.oneflow.backup` | daily 04:00 | sops+age encrypted backup, rsync offsite |
| `com.oneflow.tereza-hunter-monthly` | monthly | OSINT cherry-pick refresh |
| `com.oneflow.nextjs-dashboard` | various | Internal dashboard build |
| `com.oneflow.monologue-restart` | various | Monologue agent watchdog |
| `cz.oneflow.openspace-tunnel` | always-on | OpenSpace SSH tunnel keepalive |
| Mac cron `obsidian sync` | every 5/30 min | memory→vault, VPS→vault |
| Mac cron `ecosystem_health_check` | every 10 min | Self-healing infra (WG, Mutagen, agents) |

VPS-side má dalších ~15 timers (postfix exporter, jobs-cz refresh, backup, prom-textfile-collector atd.).

---

## Recovery

VPS Flash down? → `ai-control-plane/RECOVERY-VPS-FLASH.md` (2-min UI klik na my.contabo.com).

Mac context corrupt po session crash? → [`CLAUDE-CODE-CONTEXT-REPAIR-2026-05-04.md`](CLAUDE-CODE-CONTEXT-REPAIR-2026-05-04.md).

Mac performance degraded? → `perf-status.sh` (dashboard), `perf-tune.sh` (apply known-good settings), `perf-recovery.sh` (SIGCONT freeze release). Detail v [`PERF-TUNING-2026-05-04.md`](PERF-TUNING-2026-05-04.md).

---

## Onboarding nového sezení

```bash
# 1. Verify install
which ofs                         # → ~/.local/bin/ofs

# 2. Quick health
ofs status                        # full snapshot (Mac+VPS+queue+CLIs)

# 3. If VPS down
cat ~/Desktop/Codex/ai-control-plane/RECOVERY-VPS-FLASH.md

# 4. Heavy task → VPS, light → Mac
ofs mac                           # check Mac load first
ofs route --here "your task"      # let router decide

# 5. Mobile (Hermes Agent on VPS)
ofs phone                         # Telegram bot info
```

---

## Bezpečnost

- Žádné hardcoded secrets — `~/.credentials/master.env` (chmod 600) + sops+age (58 keys encrypted)
- Bridge skripty bind 127.0.0.1 nebo WireGuard only
- gitleaks pre-commit hook + GitHub secret-scanner
- 5 critical defense hooks (`autonomy-guard`, `gitleaks-guard`, `google-api-guard`, `hallucination-guard`, `completion-blocking-words-guard`)
- Anti-halucinace gate after every Codex delegation (`verify-codex-result.sh`)
- ntfy fallback chain: VPS local → ntfy.oneflow.cz → macOS native
- VPS SSH: key-only, fail2ban, UFW, WireGuard tunnel-only management
- Audit trail: `~/.claude/logs/ofs.jsonl` + `handoffs/` folder
- DMARC reject + adkim=s + aspf=s + MTA-STS enforce 7d + DNSSEC
- Daily encrypted backup (sops+age, ~75MB), weekly restore drill, offsite rsync

---

## Patterns worth stealing (pro tvůj vlastní setup)

Pokud chceš inspiraci pro vlastní AI control plane, mrkni primárně na:

1. **Single entry point dispatcher** ([`ofs.sh`](ai-control-plane/scripts/ofs.sh)) — místo 20 různých CLIs jeden router. Snižuje kognitivní zátěž a context switching.
2. **Anti-halucinace verify gate** ([`verify-codex-result.sh`](ai-control-plane/scripts/verify-codex-result.sh)) — po každém AI handoffu real `git diff` vs claimed changes. Eliminuje "AI tvrdí že hotovo, ale není".
3. **Cost-aware routing** ([`route-task.sh`](ai-control-plane/scripts/route-task.sh)) — auto rozhodne lean vs full mode podle scope. Šetří 50–80% nákladů.
4. **Handoff contract** ([`AGENTS.md`](AGENTS.md)) — strukturovaný report (changed files, verification, confidence per claim, residual risk). Funguje pro Codex i Claude.
5. **Resource-aware delegation** ([`resource-monitor.sh`](ai-control-plane/scripts/resource-monitor.sh)) — Mac 8GB má hranice. Auto-routing se vyhne stresing local kdykoli VPS up.
6. **Memory + recall cascade** — `grep MEMORY → memory-search MCP → Obsidian → graphiti`. Kontextový recall přes 4 vrstvy bez halucinací.
7. **Falsification-first reasoning** — pro high-stakes outputs steelman opozice před final response. `~/.claude/rules/anti-hallucination.md`.
8. **Hard-stop zone** — Claude se ptá JEN u 5 přesně definovaných zón (platby, odeslání zpráv, destrukce, FB login, strategie >100k Kč). Vše ostatní = autonomous.

---

## Stav (k 2026-05-04)

- AI control plane: **production**, daily smoke PASS, verify gate v2.1, 7 Filip browser-gates probed (4 OPEN, 1 CRITICAL: CF token).
- jobs-cz-system: **Phase 1+2+3 LIVE**, 3 portály (jobs.cz + prace.cz + StartupJobs), warm-scoring, cross-portal dedup, daily 06:30.
- Email infra: **TOP state** — DMARC reject, MTA-STS enforce, DNSSEC, 6 sister domén harmonized.
- Backup + observability: **10/10** — sops+age, daily encrypted backup, Prometheus+Grafana+Loki, 14 oneflow_* metrics, weekly restore drill.
- Performance tuning: **bullet-proof** — 6 env vars optimized, master scripts (`perf-status/tune/recovery`), Mac SIGSTOP-able heavy procs.
- Codex bridge: **verify gate v2.1** (HEAD direction tracking forward/rewound/diverged), eliminuje false-positive REVIEWs.

---

## Dokumentace (interní pointers — pro Filipa)

- Master blueprint: `~/.claude/projects/-Users-filipdopita-Desktop-Codex/memory/project_codex_bridge_overview_2026_05_02.md`
- Active rules: `~/.claude/rules/{anti-hallucination,completion-mandate,prompt-completeness,hard-stop-zone}.md`
- Knowledge router (lazy): `~/.claude/rules/knowledge-router.md`
- Workflow routing (auto-trigger skills): `~/.claude/rules/workflow-routing.md`
- VPS infra: `~/.claude/projects/-Users-filipdopita/memory/infra_vps.md`
- Sync architecture: `~/.claude/projects/-Users-filipdopita/memory/reference_sync_architecture.md`

---

Dopita
