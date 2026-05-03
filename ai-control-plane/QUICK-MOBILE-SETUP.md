# Quick Mobile Setup — Claude Code z iPhone (3 minuty)

> Filip-only TL;DR. Po dokončení máš plný Claude Code z iPhone, **stejně jako přes VS Studio**.

## Stav (2026-05-03)

- [VERIFIED] Mac Claude Code: **v2.1.126** (Remote Control vyžaduje 2.1.51+)
- [VERIFIED] Flash Claude Code: **v2.1.92** (taky OK pro RC)
- [VERIFIED] `PushNotification` permission: allow ✓
- [VERIFIED] Anthropic Max sub: připojen
- Launcher: `ofs mobile` (volá `cc-mobile.sh`)
- Native Anthropic feature, žádný HMAC/Caddy overhead

## Setup (jednorázově, ~3 min)

### Krok 1 — iPhone app (App Store)

1. Otevři App Store → vyhledej **"Claude by Anthropic"**
   Direct link: https://apps.apple.com/us/app/claude-by-anthropic/id6473753684
2. Install
3. Login **stejným Anthropic Max účtem** jako máš v Claude Code (claude.ai email + heslo / OAuth)
4. Povol notifikace když to nabídne

### Krok 2 — Připojení (každá nová session)

Na Macu (kdekoli, terminál):

```bash
ofs mobile                    # default: ~/Desktop/Codex
ofs mobile --here             # aktuální $PWD (jiný projekt)
ofs mobile --interactive      # terminál + remote naráz
```

Co uvidíš:
```
╭───────────────────────────────────────────────────╮
│  Claude Code Remote Control — Mobile Session      │
├───────────────────────────────────────────────────┤
│  Project:   /Users/filipdopita/Desktop/Codex      │
│  Session:   Filip Codex                           │
│  Mode:      server                                │
│  Version:   2.1.126                               │
╰───────────────────────────────────────────────────╯

  → Stiskni MEZERNÍK pro QR
```

1. **Stiskni MEZERNÍK** → zobrazí se QR kód v terminálu
2. **Otevři Claude app na iPhone** → tap **"Scan QR"** (nebo session list ukazuje sessions)
3. Naskenuj QR → session aktivní

### Krok 3 — Push notifikace (jednou)

Když máš RC session aktivní (na phone nebo v terminálu):

```
/config
```

Najdi "Push when Claude decides" → zapni.

Pak Claude pingne phone když:
- dlouhý task hotov
- potřebuje rozhodnutí
- ty řekneš `notify me when X` v promptu

## Denní použití

```bash
# Mac terminál
cd ~/Desktop/Codex
ofs mobile --interactive       # spustí RC + interaktivní session
                                # (píšeš z terminálu i phone naráz, sync)

# Když Mac zavřu / sleep:
# → Session přežije do ~10 min síťového výpadku
# → Když Mac vstane, automatic reconnect
```

### Always-on z VPS Flash (24/7, přežije ssh logout, Mac sleep, restart)

**One-time setup** (jediný interaktivní krok = browser login):

```bash
ofs mobile-flash-setup
# 1. ověří VPS reachability + claude version
# 2. spustí `claude auth login --claudeai` na Flash (interactive)
#    → CLI vytiskne URL → otevři v browseru NA MACU NEBO PHONE
#    → login Anthropic Max účtem → autorize
# 3. vytvoří /root/workspace-rc + git init
# 4. deployne systemd unit /etc/systemd/system/claude-rc.service
# 5. enable + start (Restart=always, survives logout — root linger=yes ✓)
# 6. ověří active + log obsahuje session URL
```

**Po setupu** (denní použití):

```bash
ofs mobile-flash status        # is-active + auth + posledních 8 řádků logu
ofs mobile-flash logs [N]      # tail Flash RC log (default 50)
ofs mobile-flash follow        # tail -f real-time
ofs mobile-flash restart       # restart service
ofs mobile-flash stop          # stop + disable
ofs mobile-flash start         # enable + start
ofs mobile-flash url           # extrahuj session URL z logu
ofs mobile-flash reauth        # po expiraci OAuth tokenu
```

**Co session "Filip Flash" dělá**:
- Service: `claude remote-control --name "Filip Flash" --spawn worktree --capacity 8`
- Workspace: `/root/workspace-rc` (git repo, každá phone session = vlastní worktree)
- Logs: `/var/log/claude-rc.log` (append, auto-rotace přes systemd)
- Restart=always (crash, network drop, 10-min idle → auto-restart 15s)
- ANTHROPIC_API_KEY explicitly unset (RC vyžaduje OAuth, ne API key)

**V Claude iOS app**: po setupu uvidíš **"Filip Flash"** v session list (computer ikona, zelená tečka = online). Tap → píšeš z phone na Flash 24/7, nezávisle na Macu.

## Co umíš z iPhone (parita s VS Studio)

| Schopnost | Phone via RC |
|---|---|
| Spustit task | ✓ |
| Vidět real-time výstup | ✓ |
| Editovat soubory | ✓ (přes `@` autocomplete + edit tool) |
| Spustit Bash příkazy | ✓ |
| Použít MCP servery | ✓ (běží na Macu, transparentně) |
| Použít skills (`/dd-emitent`, `/seo`...) | ✓ |
| Use sub-agents | ✓ |
| Push notif když hotovo | ✓ (pokud zapneš `/config`) |
| Pokračovat když Mac usne | ✓ (auto reconnect <10 min) |
| Spustit `/mcp`, `/plugin`, `/resume` | ✗ (terminal-only — interactive pickers) |
| Souběžně s Ultraplan | ✗ (mutually exclusive) |

## Bezpečnost (proč to není risk)

- **Outbound HTTPS only** — žádné porty se neotevřou na Macu nebo Flash
- **Files zůstávají lokální** — Anthropic API je jen relay zpráv
- **TLS 1.3 + multiple short-lived credentials** — každý scoped+expirable
- **HARD-STOP zone respected** — všechny safety rules z `~/.claude/CLAUDE.md` platí

## Failure modes

| Problém | Řešení |
|---|---|
| `Remote Control requires a claude.ai subscription` | `claude auth login` → claude.ai option (ne API key) |
| `Remote Control requires a full-scope login token` | Není to setup-token. `claude auth login` znovu |
| Phone neukazuje session v listu | Open Claude app, force-refresh; check že iOS app + Claude Code mají stejný account |
| QR zmizel | V terminálu znovu stiskni MEZERNÍK |
| Session umřela při dlouhém výpadku | Restart `ofs mobile` na Macu |
| Push notif nedoručeny | iPhone Settings → Notifications → Claude → allow; otevři Claude app aspoň 1× po RC start (refresh push token) |

## Reference

- Native docs: https://code.claude.com/docs/en/remote-control
- Launcher: `~/Desktop/Codex/ai-control-plane/scripts/cc-mobile.sh`
- Wired do: `ofs mobile` (alias) → `cc-mobile.sh`
- Plný overview všech 3 cest: `MOBILE-DISPATCH.md`
- ofs help: `ofs help` → sekce Mobile

Dopita
