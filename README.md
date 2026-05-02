# OneFlow AI Ekosystém — Filip Dopita

> Kompletní orchestrace Mac + VPS Flash + telefon + Obsidian. **Single entry point: `ofs`**.

## TL;DR (denní použití)

```bash
ofs status            # full snapshot (Mac, VPS, sync, queue, CLIs)
ofs route "task"      # automatické routing — lean Codex / full Codex / Claude review / strategy
ofs delegate "task"   # přímo do Codexu (implementace v souborech)
ofs review "task"     # Claude review/risk gate
ofs mac               # Mac RAM/swap/CPU detail
ofs vps               # VPS Flash health
ofs handoffs          # poslední handoffs (audit trail)
ofs logs              # ofs audit log
ofs help              # všechny commands
```

## Architektura

```
Filip
  ├─> Mac (8GB RAM, terminal + light Claude Code)
  ├─> Telefon (Telegram dispatch — Wave 2, vyžaduje VPS up)
  └─> Browser → Obsidian dashboard
        │
        ▼
   `ofs` dispatcher
        │
   ai-control-plane router (route-task.sh)
        │
   ┌────┴───────────────┐
 Codex CLI         Claude CLI
 (impl)            (review/strategy)
        │
   Mutagen/WG/SSH
        │
   VPS Flash (12GB, 24/7)
   ├ Conductor (queue + workers)
   ├ Hermes Agent (multi-platform gateway)
   ├ Paseo (agent UI)
   ├ Caddy + services
   └ Cron heavy work
```

## 4 core mantras (immutable)

1. **Výsledek > Proces** — měřitelný outcome, ne plán
2. **0 halucinací** — verify-before-claim, `[VERIFIED]/[LIKELY]/[GUESS]/[UNCERTAIN]`
3. **Token efficiency** — VPS-first, model tier (Haiku→Sonnet→Opus)
4. **Security-first** — secrets v env files, audit log, no RCE surface

Detail: `~/.claude/projects/-Users-filipdopita/memory/feedback_ecosystem_core_mantras_2026_05_02.md`

## Komponenty (co kde běží)

| Komponent | Lokace | Účel |
|---|---|---|
| `ofs` CLI | `~/.local/bin/ofs` → `ai-control-plane/scripts/ofs.sh` | Single entry point |
| `route-task.sh` | `ai-control-plane/scripts/` | Sofistikovaný router se scoringem |
| `delegate-to-codex.sh` | `ai-control-plane/scripts/` | Claude → Codex bridge (auto/lean/full) |
| `ask-claude-review.sh` | `ai-control-plane/scripts/` | Risk gate review |
| `ask-claude-strategy.sh` | `ai-control-plane/scripts/` | Strategy/architecture (no edit) |
| `resource-monitor.sh` | `ai-control-plane/scripts/` | Mac+VPS+queue load (5min cron) |
| `usage-tracker.sh` | `ai-control-plane/scripts/` | Anthropic+OpenAI consumption (daily 09:00) |
| `obsidian-dashboard.sh` | `ai-control-plane/scripts/` | Auto-update Ecosystem-Status.md (15min) |
| `security-audit.sh` | `ai-control-plane/scripts/` | Weekly security scan (Sat 03:30) |
| `update-extended.sh` | `ai-control-plane/scripts/` | MCP+Codex+npm+brew (manual or weekly) |
| `update-core.sh` | `ai-control-plane/scripts/` | gcloud+brew+VS Code ext (Sat 04:15) |
| `doctor.sh` | `ai-control-plane/scripts/` | Full diagnostic |
| Conductor | VPS `/opt/conductor/` | File-based task queue, free LLM workers |
| Hermes Agent | VPS `/usr/local/bin/hermes` | Multi-platform gateway (Telegram/Discord/Slack/WA) |
| Paseo | VPS `:6767` (WG-only) | Agent UI |

## Cron / launchd schedule

| Job | Frequency | Purpose |
|---|---|---|
| `com.filipdopita.resource-monitor` | every 5 min | Mac+VPS metrics → JSONL |
| `com.filipdopita.obsidian-dashboard` | every 15 min | Auto-update vault dashboard |
| `com.filipdopita.usage-tracker` | daily 09:00 | Cross-provider usage summary |
| `com.filipdopita.security-audit` | weekly Sat 03:30 | Defense-in-depth scan |
| `com.filipdopita.ai-core-update` | weekly Sat 04:15 | gcloud + brew + VS Code ext |
| `ecosystem_health_check.sh` (Mac cron) | every 10 min | Self-healing infra (WG, Mutagen, agents) |
| Mac cron `obsidian sync` | every 5/30 min | Memory→vault, VPS→vault |
| Mac cron `email_to_obsidian` | hourly | Email digest → vault |
| Mac cron `imessage_to_obsidian` | every 15 min | iMessage → vault (via Flash) |
| Mac cron `wa_to_obsidian` | every 30 min | WhatsApp → vault (via Flash) |

## Recovery

VPS Flash down? → `~/Desktop/Codex/ai-control-plane/RECOVERY-VPS-FLASH.md` (2-min UI klik na my.contabo.com)

## Onboarding nové sezení

```bash
# 1. Verify install
which ofs                                    # → ~/.local/bin/ofs

# 2. Quick health
ofs status                                   # full snapshot

# 3. If VPS down
cat ~/Desktop/Codex/ai-control-plane/RECOVERY-VPS-FLASH.md

# 4. Heavy task → VPS, light → Mac
ofs mac                                      # check Mac load first
ofs route --here "your task"                 # let router decide

# 5. Mobile (až Wave 2 dokončen)
ofs phone                                    # Telegram bot info
```

## Dokumentace

- **Master blueprint:** `~/.claude/projects/-Users-filipdopita/memory/project_ecosystem_master_blueprint_2026_05_02.md`
- **Core mantras:** `~/.claude/projects/-Users-filipdopita/memory/feedback_ecosystem_core_mantras_2026_05_02.md`
- **VPS infra:** `~/.claude/projects/-Users-filipdopita/memory/infra_vps.md`
- **Sync architecture:** `~/.claude/projects/-Users-filipdopita/memory/reference_sync_architecture.md`
- **Cloud orchestrator:** `~/.claude/projects/-Users-filipdopita/memory/project_cloud_orchestrator_2026_04_28.md`
- **Hermes Agent:** `~/.claude/projects/-Users-filipdopita/memory/project_hermes_agent_2026_04_30.md`
- **Conductor:** `~/.claude/projects/-Users-filipdopita/memory/project_conductor.md`
- **Paseo:** `~/.claude/projects/-Users-filipdopita/memory/project_paseo.md`
- **Obsidian dashboard:** `~/Documents/OneFlow-Vault/00-Claude-Dashboard/Ecosystem-Status.md`
- **Recovery doc:** `~/Desktop/Codex/ai-control-plane/RECOVERY-VPS-FLASH.md`
- **Mac swap analysis:** `~/Desktop/Codex/ai-control-plane/MAC-SWAP-PRESSURE-2026-05-02.md`

## Bezpečnost

- Žádné hardcoded secrets v scriptech (audit weekly + 1 finding zatím — viz `SECURITY-FINDING-2026-05-02-lachman-monitor.md`)
- Bridge skripty bind 127.0.0.1 / WG only
- gitleaks pre-commit hook
- 5 critical defense hooks (autonomy-guard, gitleaks-guard, google-api-guard, hallucination-guard, completion-blocking-words-guard)
- ntfy fallback chain: VPS local → ntfy.oneflow.cz → macOS native notification
- VPS SSH: key only, fail2ban, UFW, WireGuard tunel-only management
- Audit trail: `~/.claude/logs/ofs.jsonl` + `handoffs/` folder

## Ne-VPS fallback

Když VPS Flash down:
- Mac dispatcher (`ofs`) funguje, jen `ofs vps` selhá
- Heavy tasks počkat NEBO Mac local (s vědomím že Mac stresne pri >2GB RAM ops)
- Auto-route hint = "wait_or_mac_only" (resource-monitor.sh detekuje)
- ntfy fallback = macOS native notification

## Wave status (2026-05-02 ship)

- ✅ Wave 0: Recovery + fixes (VPS recovery doc, health check Alfa→Flash IP, memory frontmatter, Mac swap analysis)
- ✅ Wave 1: `ofs` unified dispatcher CLI
- ✅ Wave 3: resource-monitor + usage-tracker (Mac+VPS+Conductor)
- ✅ Wave 4: Obsidian dashboard auto-generated
- ✅ Wave 5: update-extended (MCP+Codex+npm+verification)
- ✅ Wave 6: Security audit (5 critical hooks ✓, 1 token finding remediation)
- ✅ Wave 7: Master README + cron schedule + smoke test
- ⏸ Wave 2: Hermes Telegram gateway (BLOCKED on VPS recovery)

Po VPS recovery:
- Filip 2-min UI klik na my.contabo.com → restart Flash
- Auto: ecosystem_health_check.sh → Mutagen resume → WG check → Conductor restart
- Manual: `ofs vps` → verify, then proceed Wave 2 (Telegram gateway config)

Dopita
