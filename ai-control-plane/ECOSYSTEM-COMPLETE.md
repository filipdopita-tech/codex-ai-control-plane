# OneFlow Ekosystem — Full Dokončení 10/10

> **Status: PRODUCTION** od 2026-05-02 21:55 CEST
> Build: 2 sessions (master 21:05–21:20, Wave 2 21:30–21:55)
> Commits: `b338064` (master) + `3155e2f` (Wave 2)
> Master Filipova úkol: kompletní ekosystém Mac + VPS + telefon + Obsidian s **4 mantras**: efekt, anti-halucinace, token efficiency, security.

---

## TL;DR

Jeden CLI (`ofs`), jedna URL (`dispatch.oneflow.cz`), tři backends (Mac, Flash VPS, telefon), všechno auditované. Status check 10 sekund (`ofs status`), dispatch z telefonu 1 POST, weekly self-audit (security + cost + handoffs).

```bash
# Daily použití
ofs status                          # ekosystem snapshot (10s)
ofs dispatch "task here"            # mobile/remote dispatch (HTTPS+HMAC)
ofs notify "msg"                    # push to phone (no LLM cost)

# Routing (delegates)
ofs route --here "task"             # intelligent router (Codex|Claude|local)
ofs delegate --here "implement X"   # Codex bridge (lean default)
ofs review --here "review commit"   # Claude review

# Maintenance
ofs vps                             # remote services + queue
ofs handoffs 10                     # last 10 audit trail entries
ofs logs 20                         # last 20 ofs CLI calls
ofs doctor                          # full diagnostic
ofs update                          # core updates (gcloud + ext + brew)
```

---

## 10/10 Wave Stav

| Wave | Komponenta | Status | Verifikace |
|---|---|---|---|
| 0 | Recovery doc + ecosystem_health_check + Mac swap analysis | ✅ | `RECOVERY-VPS-FLASH.md`, hooks live |
| 1 | `ofs` unified dispatcher (12+3 commandů) | ✅ | `~/.local/bin/ofs` symlink, audit log JSONL |
| **2** | **Hermes webhook gateway (mobile dispatch)** | ✅ | `dispatch.oneflow.cz` HTTP 202 |
| 3 | resource-monitor.sh + usage-tracker.sh | ✅ | 5min cron + daily 09:00 |
| 4 | obsidian-dashboard.sh (auto-update vault) | ✅ | 15min cron, symlink Vault → `~/.claude/logs/` |
| 5 | update-extended.sh (MCP + Codex + npm + brew) | ✅ | weekly Sat, `ofs update` |
| 6 | security-audit.sh (gitleaks + ports + 5 critical hooks) | ✅ | weekly Sat 03:30 |
| 7 | Master `Codex/README.md` + smoke test | ✅ | full E2E PASS |

**4 core mantras embedded:**
- ✅ **Efekt:** jeden CLI, žádný kontextový switching, 10s status check
- ✅ **Anti-halucinace:** všechen status = real check (systemctl/curl), ne predict
- ✅ **Token efficiency:** ofs sub-200ř output, ntfy push pro alerts (no LLM call)
- ✅ **Security:** HMAC verification, no eval, validated paths, audit log, hard-stop zone respected

---

## Architektura (full picture)

```
┌─────────────────────── TELEFON ────────────────────────┐
│  iPhone Shortcuts | ntfy app | curl | (future) Telegram │
└────────┬───────────────────────────────────────┬───────┘
         │ HTTPS POST + HMAC                     │ ntfy subscribe
         ▼                                       ▼
┌─────────────────────── VPS FLASH (10.77.0.1, Contabo) ────────────┐
│                                                                    │
│  Caddy reverse proxy (TLS auto, Let's Encrypt)                    │
│  ├─ dispatch.oneflow.cz → 127.0.0.1:8644 (Hermes)                 │
│  ├─ ntfy.oneflow.cz     → ntfy backend (push)                     │
│  └─ + 15 dalších oneflow.cz subdomén                              │
│                                                                    │
│  Hermes webhook gateway (systemd user, linger)                    │
│  ├─ /webhooks/dispatch  → Claude session (anthropic/claude-opus-4.6)│
│  └─ /webhooks/status    → system status query                     │
│  ├─ HMAC-SHA256 per-route secret                                  │
│  ├─ Rate limit 60 req/min                                         │
│  └─ Log: /root/.hermes/logs/agent.log                             │
│                                                                    │
│  Conductor (systemd) — task queue                                 │
│  ├─ /opt/conductor/queue/inbox/  (pending)                        │
│  ├─ /opt/conductor/queue/active/ (running)                        │
│  └─ workers: claude-review.py, codex.py, free.py                  │
│                                                                    │
│  Postfix MX (relay) + ntfy backend + chibisafe (planned)          │
│                                                                    │
└────────┬───────────────────────────────────────────────────────────┘
         │ WireGuard (10.77.0.0/24) + Mutagen sync
         ▼
┌─────────────────────── MAC (source of truth) ──────────────────────┐
│                                                                    │
│  ofs CLI (~/.local/bin/ofs)                                       │
│  ├─ status, vps, mac, doctor (monitoring)                         │
│  ├─ route, delegate, review, strategy (AI routing)                │
│  ├─ dispatch, notify, telegram-activate (mobile)                  │
│  └─ handoffs, logs, update, phone (maintenance)                   │
│                                                                    │
│  launchd agents (~/Library/LaunchAgents/com.filipdopita.*.plist)  │
│  ├─ resource-monitor    (5 min, Mac+VPS+Conductor metrics)        │
│  ├─ usage-tracker       (daily 09:00, cross-provider usage)       │
│  ├─ obsidian-dashboard  (15 min, vault Live snapshot)             │
│  ├─ security-audit      (weekly Sat 03:30, gitleaks+ports+hooks)  │
│  └─ ai-core-update      (existing)                                │
│                                                                    │
│  Scripts in ~/.claude/scripts/oneflow-ecosystem/ (FDA-safe)       │
│  Originals tracked in ~/Desktop/Codex/ai-control-plane/scripts/   │
│                                                                    │
│  Mutagen sync (3 sessions):                                       │
│  ├─ flash-claude-sessions  ↔ /root/.claude/                       │
│  ├─ flash-claude-config    ↔ /root/.claude/                       │
│  └─ flash-workspace        ↔ /root/workspace/                     │
│                                                                    │
│  Obsidian vault                                                    │
│  └─ 00-Claude-Dashboard/Ecosystem-Status.md                       │
│     → symlink → ~/.claude/logs/ecosystem-status.md                │
│                                                                    │
│  Claude Code (~/.claude/) — 6 rules, 50+ skills, hooks            │
│                                                                    │
└────────────────────────────────────────────────────────────────────┘
```

---

## Mobile Dispatch — Wave 2 v detailu

**Use case:** Jsem na cestě, mobilem pošlu task → executuje se na Flash → reply do logu (volitelně do Telegram/email).

### 3 cesty z telefonu

#### 1. iPhone Shortcut (~3 min setup)
```
Shortcuts.app → Create Shortcut → Name "Dispatch to Flash"
  ├─ Ask for Input: "What to dispatch?"
  ├─ Get Variable: Provided Input
  └─ Get Contents of URL:
     URL: https://dispatch.oneflow.cz/webhooks/dispatch
     Method: POST
     Headers:
       Content-Type: application/json
       X-Hub-Signature-256: sha256=<HMAC computed by Toolbox Pro/Pythonista>
     Body: {"body": "<Provided Input>"}

Add to Home Screen + Siri trigger ("Hey Siri, Dispatch")
```

> HMAC v Apple Shortcuts: vyžaduje **Toolbox Pro** ($3.99) nebo **Pythonista 3** ($9.99). Jako alternativa: použij ntfy (notify-only, žádný HMAC potřeba).

#### 2. ntfy push notifications (already working)
```
1. Stáhnout ntfy app z App Store
2. Subscribe topic: Filip
3. Server: https://ntfy.oneflow.cz
4. Auto-trigger: resource-monitor alerts, security-audit weekly,
   ofs notify "msg", high-priority system events
```

#### 3. curl from anywhere
```bash
SECRET="$(ofs dispatch --show-secret | grep Secret: | awk '{print $2}')"
PAYLOAD='{"body":"echo from terminal"}'
SIG=$(printf '%s' "$PAYLOAD" | openssl dgst -sha256 -hmac "$SECRET" -binary | xxd -p -c 64)

curl -X POST https://dispatch.oneflow.cz/webhooks/dispatch \
  -H "Content-Type: application/json" \
  -H "X-Hub-Signature-256: sha256=$SIG" \
  -d "$PAYLOAD"
```

#### 4. Telegram bot (volitelné, ~3 min Filip)
```bash
ofs telegram-activate    # zobrazí kompletní postup
```

Postup:
1. @BotFather → `/newbot` → "OneFlow Dispatch" → username `oneflow_dispatch_bot`
2. Copy HTTP API token
3. @userinfobot → copy chat_id
4. Run on Mac:
   ```bash
   ssh root@10.77.0.1 'echo TELEGRAM_BOT_TOKEN=<token> >> /root/.hermes/.env'
   ssh root@10.77.0.1 'echo TELEGRAM_ALLOWED_CHAT_IDS=<chat_id> >> /root/.hermes/.env'
   ssh root@10.77.0.1 'systemctl --user restart hermes-gateway'
   ```
5. Test: `/start` → `/dispatch "echo from telegram"` → reply do 30s

---

## Klíčové cesty

### Mac (source of truth)
| Co | Kde |
|---|---|
| Master README | `~/Desktop/Codex/README.md` |
| AI Control Plane | `~/Desktop/Codex/ai-control-plane/` |
| Wave 2 dokumentace | `~/Desktop/Codex/ai-control-plane/MOBILE-DISPATCH.md` |
| Recovery doc | `~/Desktop/Codex/ai-control-plane/RECOVERY-VPS-FLASH.md` |
| Security finding | `~/Desktop/Codex/ai-control-plane/SECURITY-FINDING-2026-05-02-lachman-monitor.md` |
| Mac swap analysis | `~/Desktop/Codex/ai-control-plane/MAC-SWAP-PRESSURE-2026-05-02.md` |
| Scripts (git tracked) | `~/Desktop/Codex/ai-control-plane/scripts/` (17 souborů) |
| Handoffs (audit) | `~/Desktop/Codex/ai-control-plane/handoffs/` (45+) |
| Scripts (TCC-safe runtime) | `~/.claude/scripts/oneflow-ecosystem/` |
| ofs symlink | `~/.local/bin/ofs` → `…/scripts/ofs.sh` |
| ofs audit log | `~/.claude/logs/ofs.jsonl` |
| Resource monitor log | `~/.claude/logs/resource-monitor.jsonl` |
| Usage daily log | `~/.claude/logs/usage-daily.jsonl` |
| Security audit reports | `~/.claude/logs/security-audit-YYYYMMDD.md` |
| Obsidian dashboard | `~/Documents/OneFlow-Vault/00-Claude-Dashboard/Ecosystem-Status.md` |
| Memory entries | `~/.claude/projects/-Users-filipdopita/memory/*.md` |
| LaunchAgents | `~/Library/LaunchAgents/com.filipdopita.*.plist` (5 plistů) |
| Credentials | `~/.credentials/*.env` (chmod 600) |

### VPS Flash (10.77.0.1)
| Co | Kde |
|---|---|
| Hermes Agent | `/usr/local/bin/hermes` → `/usr/local/lib/hermes-agent/venv/bin/hermes` |
| Hermes config | `/root/.hermes/config.yaml` (52KB, platforms.webhook enabled) |
| Hermes secrets | `/root/.hermes/.env` (chmod 600) |
| Hermes systemd | `~/.config/systemd/user/hermes-gateway.service` (linger enabled) |
| Webhook subscriptions | `/root/.hermes/webhook_subscriptions.json` (per-route HMAC) |
| Hermes log | `/root/.hermes/logs/agent.log` |
| Webhook secret | `/root/.credentials/hermes-webhook.env` (chmod 600) |
| Caddy config | `/etc/caddy/Caddyfile` (block `dispatch.oneflow.cz`) |
| Conductor | `/opt/conductor/` (queue: inbox/active/) |
| Master credentials | `/root/.credentials/master.env` (chmod 600, GHL/Apollo/Hunter/etc.) |
| WG config | `/etc/wireguard/wg0.conf` |
| Postfix queue | `/var/spool/postfix/` |

### DNS + TLS
| Subdomain | Target | TLS |
|---|---|---|
| `dispatch.oneflow.cz` | 173.212.220.67 (Caddy → Hermes) | Let's Encrypt auto |
| `ntfy.oneflow.cz` | 173.212.220.67 (Caddy → ntfy) | Let's Encrypt auto |
| 15+ dalších oneflow.cz | viz Caddyfile | LE auto |

---

## Daily / Weekly Operations

### Při startu dne (manuální, ~10 s)
```bash
ofs status                          # uvidíš co je zelené/žluté/červené
```

### Před začátkem komplexního tasku (~30 s)
```bash
ofs status                          # ekosystem zelený?
ofs dispatch --status               # remote okay?
ofs handoffs 5                      # co se nedávno dělo?
```

### Automatické cron joby (launchd)
| Job | Frequency | Co dělá |
|---|---|---|
| `com.filipdopita.resource-monitor` | každých 5 min | Mac+VPS+Conductor metrics → JSONL |
| `com.filipdopita.usage-tracker` | denně 09:00 | Cross-provider usage report |
| `com.filipdopita.obsidian-dashboard` | každých 15 min | Vault Live snapshot |
| `com.filipdopita.security-audit` | týdně Sat 03:30 | gitleaks + ports + 5 critical hooks |
| `com.filipdopita.ai-core-update` | (existing) | gcloud + VS Code ext + brew |
| `ecosystem_health_check.sh` (Flash) | každých 10 min | WG + sshd + Mutagen auto-resume |

### Týdenní self-care (sobota ráno)
```bash
ofs update                          # core updates (cca 5-10 min)
cat ~/.claude/logs/security-audit-$(date +%Y%m%d).md   # security report
ofs handoffs 50                     # týden v review
```

### Při incidentu (VPS/service down)
```bash
ofs status                          # detect
ofs vps                             # remote inspection
journalctl --user -u hermes-gateway -f --user-unit=hermes-gateway   # gateway logs
journalctl -u caddy -f              # Caddy logs (na VPS)

# Recovery (VPS down >2h)
my.contabo.com → Customer ID 14766884 → Instance 203170453 → Restart
```

---

## Smoke Test Checklist

```bash
# Quick health (≈10s)
[ ] ofs status                              # všechny komponenty zelené
[ ] launchctl list | grep filipdopita | wc -l    # = 6 agents
[ ] mutagen sync list | grep -c Watching         # = 3 active

# Mobile dispatch (≈30s)
[ ] ofs dispatch --status                   # 202 accepted
[ ] ofs dispatch "echo round-trip"          # 202 accepted
[ ] ofs notify "smoke test"                 # ntfy push to phone
[ ] curl -s https://dispatch.oneflow.cz/webhooks/dispatch -d '{}' | grep -q "Invalid signature"   # 401 ✓

# AI routing (≈60s)
[ ] ofs route --here "what's in this repo"  # router funguje
[ ] ofs delegate --here "lint check"        # Codex bridge
[ ] ofs review --here "review last commit"  # Claude review

# Audit trail
[ ] ofs handoffs 10                         # recent handoffs visible
[ ] ofs logs 20                             # ofs CLI history
[ ] cat ~/Documents/OneFlow-Vault/00-Claude-Dashboard/Ecosystem-Status.md | head -30   # dashboard data
[ ] ssh root@10.77.0.1 "systemctl --user is-active hermes-gateway"   # = active
[ ] git log --oneline -5                    # commits visible
```

---

## Security Model

### Co je chráněné
- **HMAC-SHA256** verification per webhook request (per-route 256-bit secret)
- **Caddy edge filter** — POST bez `X-Hub-Signature-256` = 401 (early reject)
- **Rate limit** 60 req/min per webhook route
- **TLS 1.3** (Let's Encrypt přes Caddy ACME tls-alpn-01)
- **HARD-STOP zone** v dispatch promptu: payments, sending, destruction, FB login, strategy >100k = STOP + report only
- **Audit trail** ve 3 vrstvách:
  - Mac: `~/.claude/logs/ofs.jsonl` (CLI calls)
  - VPS: `/root/.hermes/logs/agent.log` (Hermes deliveries)
  - Caddy: journald (HTTP access logs)
- **No outbound** bez explicit `--deliver` config (Hermes default = log only)
- **No CORS** — endpoint není určený pro browser
- **chmod 600** na všech credentials (`/root/.credentials/*.env`, `/root/.hermes/.env`, `/root/.hermes/webhook_subscriptions.json`)
- **No secrets v repu** — `gitleaks` weekly check, `lachman-monitor.sh` env-sourced
- **PreToolUse hook** `google-api-guard.sh` — blokuje paid Google API (GCP cost zero tolerance)
- **5 critical hooks** monitorováno security-audit.sh:
  - `google-api-guard.sh` (paid Google API blocker)
  - `autonomy-guard.sh` (HARD-STOP zone enforcement)
  - `cost-zero-tolerance` rule
  - Pre-commit `gitleaks` scan
  - SSH `prohibit-password` config

### Známá rizika a mitigace
| Riziko | Mitigace | Status |
|---|---|---|
| Webhook secret leak | per-route secret + chmod 600 + audit log | ✅ |
| Hermes prompt injection (z webhook body) | HARD-STOP wording v prompt template + log review | ⚠️ monitoring |
| VPS Flash compromise | UFW deny default + WG-only management + fail2ban | ✅ |
| Mac TCC bypass via launchd | scripty v `~/.claude/scripts/oneflow-ecosystem/` (FDA-safe path) | ✅ |
| Cloudflare API key compromise | chmod 600 + scoped to oneflow.cz zone only | ✅ |
| Mutagen sync corrupt | snapshot before resume + manual re-init available | ✅ |
| Hermes gateway crash | systemd Restart=always + linger | ✅ |
| Caddy cert renewal fail | Let's Encrypt auto-renew + journald alerts | ✅ |

---

## Failure Modes & Recovery

| Symptom | Diagnose | Fix |
|---|---|---|
| `ofs status` ukáže VPS DOWN | `ping -c 3 173.212.220.67` | my.contabo.com restart instance |
| WG tunel down ale public UP | `ssh root@173.212.220.67 "wg show"` | `systemctl restart wg-quick@wg0` |
| Mutagen 3 paused | `mutagen sync list` | `mutagen sync resume <name>` (auto-resume každých 10 min) |
| Hermes webhook 502 | `ssh root@10.77.0.1 systemctl --user status hermes-gateway` | `systemctl --user restart hermes-gateway` |
| Caddy down | `ssh root@10.77.0.1 systemctl status caddy` | `systemctl restart caddy` (check Caddyfile validate first) |
| HTTPS 401 z dispatch | wrong HMAC | `ofs dispatch --show-secret` (refresh secret) |
| HTTP 429 rate limit | Hermes 60/min hit | wait 60s |
| launchd job `Operation not permitted` | TCC denied path | ověř script v `~/.claude/scripts/oneflow-ecosystem/`, `xattr -c`, plist path |
| Obsidian dashboard stale (>1h) | obsidian-dashboard launchd not running | `launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/com.filipdopita.obsidian-dashboard.plist` |
| ofs.jsonl missing | `~/.claude/logs/` ownership | `mkdir -p ~/.claude/logs && touch ~/.claude/logs/ofs.jsonl` |
| Hooks broken | `~/.claude/settings.json` corrupt | restore z `~/.claude/settings.json.bak.20260502_185441` |
| Mac swap >90% | resource-monitor flag + ntfy | `osascript -e 'tell app "Spotify" to quit'`, close VS Code instances |

---

## Co NEDĚLAT

- ❌ Nemodifikuj `~/.claude/scripts/oneflow-ecosystem/*.sh` přímo — vždy edituj originál v `~/Desktop/Codex/ai-control-plane/scripts/` (git tracked) → sync (cp + xattr -c + chmod +x) → reload launchd plist
- ❌ Nepouštěj `update-extended.sh` bez Filipova vědomí (10-30 min, mění brew/npm/extensions)
- ❌ Nezakládej nový GCP projekt / nepřidávej Google API (cost-zero-tolerance.md, 3 incidenty 2026-04-17/24/27)
- ❌ Nepiš secrets do `handoffs/` folder (gitleaks-guard hook to chytne)
- ❌ Nesmaž symlink `~/Documents/OneFlow-Vault/00-Claude-Dashboard/Ecosystem-Status.md` (vede na `~/.claude/logs/ecosystem-status.md`)
- ❌ Nezapínej Caddy log block s file output bez správného ownership (caddy user permissions)
- ❌ Neměň webhook subscription secret bez updatu na všech klientských zařízeních (iPhone Shortcut, curl skripty)
- ❌ Nepřidávej Hermes webhook `--deliver telegram/slack/discord` bez Filipova explicit (může poslat outbound zprávu)
- ❌ Nepoužívej Hermes pro hard-stop zone akce (platby/odeslání/destrukce/FB-login/strategy >100k)

---

## Filipovy volitelné next-step (žádný blokátor)

### 🟢 Quick wins (~3 min každý)
1. **iPhone Shortcuts setup** pro tap-to-dispatch z home screen
   - Postup: `MOBILE-DISPATCH.md` § iPhone Shortcuts setup
   - Vyžaduje: Toolbox Pro nebo Pythonista (HMAC compute)

2. **Telegram bot** pro dvoucestnou konverzaci
   - Postup: `ofs telegram-activate`
   - @BotFather → /newbot → token → ssh append do `.env` → `systemctl --user restart hermes-gateway`

3. **ntfy app subscribe** topic `Filip` (pokud ještě nemáš)
   - App Store → ntfy → Subscribe → server: `https://ntfy.oneflow.cz`, topic: `Filip`

### 🟡 Medium-term enhancements
4. **chibisafe deployment** pro `file.oneflow.cz` (file vault, alternativa Google Drive)
   - Reference: `~/.claude/projects/-Users-filipdopita/memory/reference_beads_chibisafe_plunk_2026_04_30.md`

5. **GlitchTip self-host** pro `errors.oneflow.cz` (Sentry alternative pro Conductor/scrapers/Hermes)
   - Reference: tamtéž § GlitchTip

6. **iPhone Shortcuts library expansion**:
   - "Status check" → ofs dispatch --status
   - "Quick deploy" → ofs delegate (specific repo)
   - "Last handoffs" → status query

### 🔵 Long-term considerations
7. **Cloud backup** pro `~/.credentials/` (encrypted) — ztráta = re-create všech API kláčů
8. **Conductor → Hermes managed agents migration** (Anthropic Managed Agents Q3 2026 GA)
9. **Mac swap permanent fix** (currently 89-93% routinely) — buď víc RAM nebo víc tasků na VPS
10. **Hermes session continuity** — currently each webhook = new session, lost context. Pro long-running dispatches: integrate s Conductor queue.

---

## Reference (memory pointery)

### Filipovy core rules (čti PŘED jakoukoli prací)
- `~/.claude/rules/anti-hallucination.md` — verify-before-claim
- `~/.claude/rules/completion-mandate.md` — dokonči, ne plánuj
- `~/.claude/rules/hard-stop-zone.md` — 5 zón kdy se ptát
- `~/.claude/rules/cost-zero-tolerance.md` — Google API ban (3 incidenty)
- `~/.claude/rules/security-hardening.md` — secrets, SSH, hooks
- `~/.claude/rules/codex-bridge-routing.md` — Claude vs Codex routing
- `~/.claude/rules/fb-scrape-safety.md` — FB/Meta account safety
- `~/.claude/rules/prompt-completeness.md` — multi-bod prompt completeness
- `~/.claude/rules/oneflow-all.md` — voice + brand + banned words

### Master blueprints (Wave kontext)
- `~/.claude/projects/-Users-filipdopita/memory/project_ecosystem_master_blueprint_2026_05_02.md`
- `~/.claude/projects/-Users-filipdopita/memory/feedback_ecosystem_core_mantras_2026_05_02.md`
- `~/.claude/projects/-Users-filipdopita/memory/MEMORY.md` (manifest)

### Existující ekosystem reference
- `~/.claude/projects/-Users-filipdopita/memory/project_cloud_orchestrator_2026_04_28.md` — Conductor pattern
- `~/.claude/projects/-Users-filipdopita/memory/project_hermes_agent_2026_04_30.md` — Hermes install
- `~/.claude/projects/-Users-filipdopita/memory/project_conductor.md` — Conductor systemd
- `~/.claude/projects/-Users-filipdopita/memory/project_paseo.md` — Paseo daemon
- `~/.claude/projects/-Users-filipdopita/memory/infra_vps.md` — Flash specs + services
- `~/.claude/projects/-Users-filipdopita/memory/reference_sync_architecture.md` — Mutagen + WG
- `~/.claude/projects/-Users-filipdopita/memory/feedback_vps_first.md` — VPS-first pravidla

---

## Git Trail

```
3155e2f feat(wave2): mobile dispatch via Hermes webhook gateway — ekosystem 10/10
b338064 feat: ekosystem master build — ofs dispatcher + monitor + dashboard + security audit
d07543b test: smoke-test handoffs from test-bridge.sh
f86a412 init: Codex AI control plane workspace
```

**3155e2f (Wave 2):** 432+/134- lines, 3 files (ofs.sh + HANDOFF + MOBILE-DISPATCH.md)
**b338064 (Master):** 18 files, 2459 inserts (ofs + monitor + dashboard + security + 4 launchd)

---

## Verifikace 10/10

```bash
# Run this NOW to verify ekosystem complete
echo "=== EKOSYSTEM 10/10 VERIFICATION ==="

echo "1. ofs CLI installed?"          ; [ -x ~/.local/bin/ofs ] && echo "  ✓" || echo "  ✗"
echo "2. ofs status works?"            ; ~/.local/bin/ofs status >/dev/null 2>&1 && echo "  ✓" || echo "  ✗"
echo "3. VPS Flash reachable?"         ; ssh -o ConnectTimeout=5 root@10.77.0.1 "true" 2>/dev/null && echo "  ✓" || echo "  ✗"
echo "4. Hermes gateway running?"      ; ssh root@10.77.0.1 "systemctl --user is-active hermes-gateway" 2>/dev/null | grep -q active && echo "  ✓" || echo "  ✗"
echo "5. Webhook 8644 listening?"      ; ssh root@10.77.0.1 "ss -tlnp | grep -q ':8644'" 2>/dev/null && echo "  ✓" || echo "  ✗"
echo "6. dispatch.oneflow.cz HTTPS?"   ; curl -s -o /dev/null -w "%{http_code}" --max-time 10 -X POST https://dispatch.oneflow.cz/webhooks/dispatch -d '{}' | grep -q 401 && echo "  ✓" || echo "  ✗"
echo "7. ofs dispatch round trip?"     ; ~/.local/bin/ofs dispatch "10/10 verify" 2>&1 | grep -q "202" && echo "  ✓" || echo "  ✗"
echo "8. ntfy notify works?"           ; ~/.local/bin/ofs notify "10/10 verify" 2>&1 | grep -q "Notified" && echo "  ✓" || echo "  ✗"
echo "9. launchd 6 agents loaded?"     ; [ "$(launchctl list 2>/dev/null | grep -c filipdopita)" -ge 6 ] && echo "  ✓" || echo "  ✗"
echo "10. Obsidian dashboard recent?"  ; [ -f ~/.claude/logs/ecosystem-status.md ] && [ "$(($(date +%s) - $(stat -f %m ~/.claude/logs/ecosystem-status.md)))" -lt 1800 ] && echo "  ✓ (<30 min old)" || echo "  ✗"

echo ""
echo "All 10/10 = ekosystem complete."
```

---

## Final note

**Toto je production state.** Žádný čekající blokátor, žádná čekající Filipova akce. Ekosystem běží, dispatcher funguje, audit trail kompletní, security hardened, recovery dokumentováno.

Wave 0–7 (master commit 21:20) + Wave 2 (Wave 2 commit 21:55) = **10/10 ✅**

Volitelné enhancements (iPhone Shortcuts, Telegram bot, chibisafe, GlitchTip) jsou dokumentované jako future work, žádný critical path.

**Primary entry points:**
- Daily: `ofs status`
- Mobile: `ofs dispatch "task"` nebo iPhone Shortcut
- Recovery: `ai-control-plane/RECOVERY-VPS-FLASH.md`
- Full doc: tento soubor
- Continuation: `ai-control-plane/HANDOFF-NEXT-SESSION.md`

Dopita
