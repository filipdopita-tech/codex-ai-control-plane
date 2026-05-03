# iPhone 15 — Bidirectional Setup (5 min, once)

> Cíl: dát Claude max možný přístup k tvému iPhone v rámci Apple iOS sandboxu.
> **Honest scope:** Apple iOS sandbox NEDOVOLUJE Claude přímou kontrolu iPhonu (file system, terminal, app launch). Setup níže = **bidirectional bridge** přes oficiální Apple integrace + cloud relay. Ekvivalent přístupu jako přes Mac terminál není možný a NEEXISTUJE u žádného AI tooling pro iOS bez jailbreak.
>
> Co reálně získáš = **maximální IO**: Filip → Claude (instant) + Claude → Filip's iPhone (push, file delivery, voice trigger, iMessage).

## 4 odkazy na install (App Store, click)

| App | Účel | Odkaz |
|---|---|---|
| **Claude by Anthropic** | full Claude session na iPhonu, sees "Filip Flash" | https://apps.apple.com/us/app/claude-by-anthropic/id6473753684 |
| **ntfy** | push notif z Flash → iPhone (auth alerts, build hotov, Claude pingne) | https://apps.apple.com/app/ntfy/id1625396347 |
| **Pushcut** | Claude → iPhone akce (run shortcut, voice notif, vibrate) | https://apps.apple.com/app/pushcut/id1471477085 |
| **Shortcuts** | built-in iOS app | (already installed) |

## 5 step setup (5 min, once)

### 1. Claude iOS app (1 min)
- Install + Login **stejným Anthropic Max účtem** jako Mac (`dlouhyphoto@gmail.com`)
- Settings → Notifications → **Allow**
- Otevři Sessions list → uvidíš **"Filip Flash"** (computer ikona, zelená tečka = online)
- Tap → píšeš do same Claude session jako z Mac terminálu
- V running session: `/config` → "Push when Claude decides" → **ON**

### 2. ntfy app (1 min, push z Flash → iPhone)
- Install + Open
- Tap **"+"** → Add subscription
- Server: `https://ntfy.oneflow.cz`
- Topic: `Filip`
- ✓ Subscribe → uvidíš live všechny push z Mac/Flash

Test z Mac:
```bash
ofs notify "Test push z Macu" --priority high
```
→ iPhone vibruje + zobrazí notifikaci do 2s.

### 3. Pushcut app (1 min, Claude → iPhone akce)
- Install + Login (free tier = 30 actions/měsíc, dost pro sporadic Claude → iPhone)
- Settings → **API** → Copy "API Key" + "Webhook URL"
- Pošli oba zpátky do tohoto chatu (nebo zapiš do `~/.credentials/pushcut.env`):
  ```
  PUSHCUT_API_KEY=...
  PUSHCUT_WEBHOOK_URL=...
  ```
- Pak Claude může z Mac posílat: `ofs pushcut "title" "subtitle"` → iPhone push s custom akcí

### 4. iOS Shortcuts (2 min, voice trigger Claude)
- Otevři **Shortcuts** app na iPhonu
- Tap "+" → Add Action → "Get Contents of URL"
- Configure URL: `https://dispatch.oneflow.cz/webhooks/dispatch`
- Method: POST, Headers viz `MOBILE-DISPATCH.md` § HMAC setup (nebo: Hey Siri, "show iPhone Shortcuts secret" → Claude session ti ho ukáže)
- Save jako "Dispatch to Flash" → Add to Home Screen + Siri trigger "Hey Siri, Dispatch"
- Test: "Hey Siri, dispatch echo from phone" → Claude session na Flash dostane prompt + odpoví

### 5. iCloud Drive bridge (0 min, transparent)
- Filip's iCloud Drive už zapnutý ✓ (Desktop + Documents synced)
- Claude może psát do `~/Library/Mobile Documents/com~apple~CloudDocs/Claude-Inbox/`
- Soubor se automaticky objeví v **Files app** na iPhonu (záložka iCloud Drive → Claude-Inbox)
- Použití: `ofs icloud put REPORT.pdf` nebo `ofs icloud note "stěžejní rozhodnutí"`

## Co Claude UMÍ s iPhonem (po setupu)

| Akce | Mechanism | Trigger |
|---|---|---|
| Pošli ti push notif | ntfy → ntfy.oneflow.cz/Filip | `ofs notify "msg"` |
| Pingne přes iMessage (vibrace, banner) | osascript Mac → iCloud relay | `ofs imsg "msg"` |
| Pošle soubor na iPhone Files | iCloud Drive Claude-Inbox | `ofs icloud put <file>` |
| Trigger iOS Shortcut/automation | Pushcut webhook | `ofs pushcut "title"` |
| Voice notif s mluveným textem | Pushcut Audio action | `ofs pushcut --speak "věta"` |
| Open URL na iPhone | Pushcut "Open URL" action | `ofs pushcut --url https://...` |
| Read iPhone clipboard | ❌ NELZE (iOS sandbox) | — |
| Read iPhone messages/contacts/photos | ❌ NELZE | — |
| Run iPhone app | ❌ NELZE | — |
| SSH do iPhonu | ❌ NELZE bez jailbreak | — |

## Co iPhone UMÍ pro Claude (full access)

| Akce | Mechanism |
|---|---|
| Plná Claude session (chat, files, MCP, sub-agents) | Claude iOS app → "Filip Flash" |
| One-shot prompt přes voice | Siri Shortcut "Hey Siri, Dispatch" → Hermes webhook |
| Browse Mac/Flash files | Claude session → Read tool → vidíš full filesystem |
| Run Bash/edit kódu | Claude session → Bash/Edit tool |

## Auto-trigger nápady (volitelné, po setupu)

Pushcut Personal Automation server umožní Claude triggernout:
- "Když přijde ntfy s tagem `urgent` → vibrate + speak text"
- "Když přijde ntfy s `auth-expired` → otevři claude.ai/login"
- "Když Claude session dokončí task → notification s Quick Reply 'Continue/Stop'"

Setup v Pushcut app: Settings → Automations → Add → Trigger "Webhook received" → Action.

## Reference
- Hermes webhook detail: `MOBILE-DISPATCH.md` § Webhook
- ntfy detail: `MOBILE-DISPATCH.md` § ntfy push setup
- Multi-account workflow: `MULTI-ACCOUNT-WORKFLOW.md`
- Quick mobile recap: `QUICK-MOBILE-SETUP.md`

Dopita
