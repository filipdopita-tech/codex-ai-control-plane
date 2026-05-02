# Mobile Dispatch — z telefonu spustíš task na VPS

> Wave 2 deliverable. Status: **LIVE** od 2026-05-02 21:50 CEST.
> Endpoint: `https://dispatch.oneflow.cz/webhooks/dispatch`

## Co to dělá

Pošleš HTTP POST z telefonu (nebo jakéhokoli zařízení), Hermes Agent na Flash VPS spustí task v Claude session, výsledek loguje do `/root/.hermes/logs/agent.log`. Volitelně může výsledek doručit zpátky přes Telegram/Slack/Discord/email (config: `--deliver` při subscribe).

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
