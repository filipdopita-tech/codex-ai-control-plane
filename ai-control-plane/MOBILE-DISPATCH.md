# Mobile Dispatch — telefon = full Claude Code session

> Status: **LIVE** od 2026-05-02 (Hermes webhook) + **2026-05-03 (native RC)**.
> 3 cesty od full IDE-grade kontroly po one-shot push.

## Tři cesty (vyber podle úkolu)

| # | Cesta | Trigger | Co vidíš | Setup |
|---|---|---|---|---|
| 1 | **Native Remote Control** (PRIMARY) | `ofs mobile` na Mac | full session, real-time chat, files, MCPs | Anthropic Claude app + scan QR (~30s) |
| 2 | **Hermes webhook** | curl/Shortcuts POST | log výstup (no real-time) | HMAC + iOS Shortcuts (~3 min) |
| 3 | **ntfy push** | `ofs notify` | jen notifikace | ntfy iOS app (~1 min) |

## 1) Native Remote Control (RC) — VS Studio-grade z phone

> Anthropic feature (research preview, únor 2026). Vyžaduje Claude Code v2.1.51+ (instalováno: 2.1.126). Dostupné na Pro/Max/Team/Enterprise plans, **NE pro API-key auth**.

### Co to dělá

Claude Code session běží na tvém Macu (nebo Flash VPS). Z iPhone se připojíš přes Anthropic API relay (outbound HTTPS only, žádné inbound porty). Vidíš stejnou session, stejné files, stejné MCP servery, můžeš psát zprávy z phone i z terminálu naráz — sync v reálném čase. Survival: pokud Mac usne nebo padne network <10 min, session se reconnectne sama.

### Quickstart

```bash
# 1. Stáhni Claude app na iPhone (jednorázově)
#    App Store: "Claude by Anthropic"
#    https://apps.apple.com/us/app/claude-by-anthropic/id6473753684
#    Login: stejný Anthropic Max account jako Claude Code

# 2. Spusť RC session na Macu
ofs mobile                    # default: Codex root
ofs mobile --here             # aktuální $PWD
ofs mobile --interactive      # terminál + remote naráz
ofs mobile /path "Title"      # explicit project + custom session title

# 3. Stiskni MEZERNÍK v terminálu → zobrazí QR
# 4. V Claude iOS app: scan QR
# 5. Hotovo — píšeš z phone, vidíš z Macu, plný control
```

### Push notifikace (volitelné, doporučené)

```bash
# V běžící session (terminál nebo phone):
/config
# → "Push when Claude decides" → toggle ON
```

Claude pak automaticky pingne phone když:
- dlouhý task dokončí
- potřebuje rozhodnutí (HARD-STOP zone)
- explicit `notify me when X` v promptu

### RC z VPS Flash (always-on bonus)

Filip běžně používá Mac, ale když je daleko (cesta, sleep, restart), RC umírá. Pro persistent session:

```bash
# Jednorázový setup na Flash (vyžaduje browser flow pro /login):
ssh root@10.77.0.1
tmux new -s claude-rc
cd /root/workspace
claude              # první run → /login → claude.ai OAuth (open URL na phone)
# → po loginu Ctrl-D, pak:
claude remote-control --name "Filip Flash" --spawn worktree
# Ctrl-b d (detach tmux). Session běží 24/7.
# Reattach: tmux attach -t claude-rc
```

Limity:
- Trvalé poll → minimální RAM use (~150MB Flash má dost)
- Worktree spawn = každý mobile request = vlastní git checkout (no conflict)
- Po síťovém výpadku >10 min → session umírá, restart manual
- RC nepodporuje API key auth (Filip Max OAuth = OK)

### Bezpečnost RC

- **Outbound HTTPS only** — žádné inbound porty na Mac/Flash
- **Žádné files do cloudu** — filesystem zůstává lokální
- **Anthropic API jako relay** — TLS, multiple short-lived credentials
- **HARD-STOP zone respected** — RC sessions dědí všechna pravidla z `~/.claude/CLAUDE.md`

### Limitace RC

- Local-only commands z phonu nejedou: `/mcp`, `/plugin`, `/resume` (interactive pickers)
- Ultraplan disconnects RC (nelze běžet souběžně)
- 1 RC session per claude proces (server mode podporuje multi)
- Pokud zavřeš terminál nebo padne `claude` proces → session končí

## 2) Hermes webhook — one-shot dispatch (no terminal needed)

Použij když nemáš zapnutý Mac/Flash terminál a chceš jen poslat task. Výstup nejde do real-time chatu, ale do logu.

## Architektura

```
Telefon (iOS Shortcuts | curl | ntfy app)
    │ HTTPS POST + HMAC-SHA256 signature
    ▼
Caddy reverse proxy (dispatch.oneflow.cz, TLS)
    │
    ▼
Hermes webhook gateway (127.0.0.1:8644, systemd user service)
    │ HMAC verify → rate limit → render prompt → dispatch
    ▼
Claude session (model: anthropic/claude-opus-4.6 via OpenRouter)
    │ Execute task with 4 mantras (efekt, anti-halucinace, token efficiency, security)
    ▼
Output → /root/.hermes/logs/agent.log (or --deliver target)
    │
    ▼
ntfy.oneflow.cz → telefon push (out-of-band)
```

## Endpoints

| Route | URL | Použití |
|---|---|---|
| dispatch | `https://dispatch.oneflow.cz/webhooks/dispatch` | Free-form task: `{"body":"<task>"}` |
| status | `https://dispatch.oneflow.cz/webhooks/status` | System status query: `{}` |

Per-route HMAC secrety v `/root/.hermes/webhook_subscriptions.json` (chmod 600).

## Nejrychlejší použití (z Macu)

```bash
ofs dispatch "echo hello from filip"           # HTTP 202 + delivery_id
ofs dispatch --status                          # systém status request
ofs dispatch --show-secret                     # ukáže HMAC secret pro Shortcuts
ofs notify "Test push"                         # ntfy push to phone (no LLM)
ofs notify --priority high "Critical alert"    # high priority push
```

## iPhone Shortcuts setup (~3 min)

1. **Get HMAC secret:**
   ```bash
   ofs dispatch --show-secret
   # Copy: <route_secret>
   ```

2. **Open Shortcuts app → "+" → Create Shortcut → Name: "Dispatch to Flash"**

3. **Add actions:**
   - **"Ask for Input"** (text) — Prompt: "What to dispatch?"
   - **"Get Variable"** → "Provided Input"
   - **"Get Contents of URL"**:
     - URL: `https://dispatch.oneflow.cz/webhooks/dispatch`
     - Method: `POST`
     - Headers:
       - `Content-Type` = `application/json`
       - `X-Hub-Signature-256` = `sha256=<HMAC of request body>` ← needs computed sig
     - Request Body (JSON): `{"body": "<Provided Input>"}`

4. **Add to Home Screen** + **Siri trigger**: "Hey Siri, Dispatch"

> **Note pro iPhone Shortcuts HMAC:** Apple Shortcuts neumí HMAC nativně. Použij **Toolbox Pro** ($3.99) nebo **Pythonista 3** ($9.99) pro `hmac.sha256(secret, body).hexdigest()`. Alternativa: použij `ntfy notify` z iOS Shortcuts (notify-only, žádný LLM call) — to je 100% nativně podporované.

## ntfy push setup (already working)

- Server: `https://ntfy.oneflow.cz` (Caddy + ntfy backend)
- iOS app: [ntfy on App Store](https://apps.apple.com/app/ntfy/id1625396347)
- Topic to subscribe: `Filip`
- Auto-trigger: resource-monitor.sh, security-audit.sh, ofs notify command

## Curl from anywhere

```bash
SECRET="<from: ofs dispatch --show-secret>"
TASK="echo hello from terminal"
PAYLOAD=$(printf '{"body":"%s"}' "$TASK")
SIG=$(printf '%s' "$PAYLOAD" | openssl dgst -sha256 -hmac "$SECRET" -binary | xxd -p -c 64)

curl -X POST https://dispatch.oneflow.cz/webhooks/dispatch \
  -H "Content-Type: application/json" \
  -H "X-Hub-Signature-256: sha256=$SIG" \
  -d "$PAYLOAD"
# → {"status":"accepted","route":"dispatch","event":"unknown","delivery_id":"..."}
```

## Telegram option (1-click activate, ~3 min Filip)

Webhook gateway je **primary** path (works now). Telegram je **secondary alternativa** kdyby Filip preferoval dvoucestnou konverzaci přes Telegram bot:

```bash
ofs telegram-activate   # zobrazí kompletní postup
```

Postup ve zkratce:
1. @BotFather → /newbot → "OneFlow Dispatch" → username: `oneflow_dispatch_bot`
2. Copy HTTP API token
3. @userinfobot → copy chat_id
4. Run on Mac:
   ```bash
   ssh root@10.77.0.1 'echo TELEGRAM_BOT_TOKEN=<token> >> /root/.hermes/.env'
   ssh root@10.77.0.1 'echo TELEGRAM_ALLOWED_CHAT_IDS=<chat_id> >> /root/.hermes/.env'
   ssh root@10.77.0.1 'systemctl --user restart hermes-gateway'
   ```
5. Test in Telegram: `/start` → `/dispatch "echo from telegram"`

## Security model

- **HMAC verification** za každý request (per-route secret, 256-bit, `hmac.compare_digest`)
- **Caddy edge filter** — POST bez `X-Hub-Signature-256` headeru = 401 (early reject)
- **Rate limit** v Hermes (interní): 60 req/minute per route
- **No outbound** bez explicit `--deliver` config — defaultně jen log
- **HARD-STOP** prompt template: webhook prompt obsahuje "STOP for: payments, sending messages, destruction, FB login, strategy >100k"
- **Audit trail**: `/root/.hermes/logs/agent.log` + `~/.claude/logs/ofs.jsonl` (Mac side)
- **TLS 1.3** přes Let's Encrypt (Caddy auto-cert)
- **No CORS** — endpoint není určen pro browser-side calls

## Failure modes

| Scenario | Response | Action |
|---|---|---|
| VPS Flash down | `ofs dispatch` → exit 2 + recovery doc reference | Restart via my.contabo.com |
| WG tunel down ale public IP UP | `ofs dispatch` použije public route automaticky | Žádná akce |
| Caddy down | HTTPS 502 | `ssh root@10.77.0.1 systemctl restart caddy` |
| Hermes gateway crashed | HTTPS 502 (Caddy proxy can't reach 8644) | `systemctl --user restart hermes-gateway` (linger enabled) |
| Wrong secret | HTTP 401 `{"error":"Invalid signature"}` | Refresh: `ofs dispatch --show-secret` |
| Rate limit hit | HTTP 429 | Wait 60s |
| OpenRouter API down | Task accepted (202) but log shows error | Check `journalctl --user -u hermes-gateway` |

## Reference

- Webhook code: `/usr/local/lib/hermes-agent/gateway/platforms/webhook.py`
- Subscriptions: `/root/.hermes/webhook_subscriptions.json` (chmod 600)
- Caddy config: `/etc/caddy/Caddyfile` (block `dispatch.oneflow.cz {}`)
- DNS: Cloudflare A record `dispatch.oneflow.cz → 173.212.220.67` (TTL 300, unproxied)
- Systemd unit: `~/.config/systemd/user/hermes-gateway.service` (linger enabled — survives logout)
- Logs: `journalctl --user -u hermes-gateway -f` + `/root/.hermes/logs/agent.log`
- Memory pointer: `~/.claude/projects/-Users-filipdopita/memory/project_hermes_agent_2026_04_30.md`

Dopita
