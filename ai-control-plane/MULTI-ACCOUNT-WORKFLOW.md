# Multi-Account Mobile RC Workflow

> Status: **LIVE** od 2026-05-03 (session continuation reference)
> Tento dokument = handoff pro novou Claude Code session. Otevři ho v každé nové session aby měl Claude full context.

## Filipova vize (architektonický cíl)

1. **Multi-account agnostic** — Filip + kolegové se střídají pod různými Anthropic účty (dlouhyphoto, filipdopita). Workflow musí podporovat snapshot/switch bez ztráty session state. ✓ DONE
2. **JEN Filipův přístup** — k VPS Flash mají přístup pouze Filipova zařízení (Mac přes WG SSH ed25519, iPhone 15 přes Claude iOS app + 2FA na service account). ✓ DONE (ad iPhone bind: viz § "iPhone hardening")
3. **Ekosystém běží na VPS** — rámka (CLAUDE.md, rules, knowledge, skills) musí být LOCAL na Flash, ne závislá na SSHFS Mac mountu. Phone session přežije Mac sleep / network drop. ✓ DONE 2026-05-03
4. **Tásky se odbavují na VPS** — claude-rc + worktree spawn + Codex bridge → vše běží na Flash compute. ✓ DONE
5. **Autonomní + adaptivní** — auto-detection OAuth expiry + ntfy push + auto-sync ekosystému. ✓ DONE 2026-05-03

## Stav (2026-05-03 — verified)

| Komponenta | Stav |
|---|---|
| Flash systemd service `claude-rc` | active, Restart=always, linger=yes |
| Active account | `dlouhyphoto@gmail.com` (orgId d3a829ce, Anthropic Max) |
| Workspace | `/root/workspace-rc` (git init, spawn=worktree, capacity 8) |
| Ekosystém inheritance | **LOCAL** `CLAUDE_CODE_ADDITIONAL_DIRECTORIES_CLAUDE_MD=/root/.claude-ecosystem` (Mac mirror) — **2026-05-03 lift-shift** |
| Ekosystém auto-sync | cron `/etc/cron.d/claude-ecosystem-sync` — daily 00:30 UTC + on-demand `ofs mobile-flash sync-ecosystem` |
| Auth health check | cron `/etc/cron.d/claude-flash-auth-check` — každých 6h, ntfy push při expiry |
| Session URL | re-extract: `ofs mobile-flash url` |
| Session jméno v iOS app | "Filip Flash" (computer ikona, zelená tečka = online) |
| Backup credentials | `/root/.claude/creds-backup/dlouhyphoto.{json,oauth.json}`, `filipdopit.json` (stale) |
| iPhone identity bind | service account = osobní Filipův Anthropic + 2FA + Face ID + Family Screen Time (viz § iPhone hardening) |

## Filesystem reference

```
/Users/filipdopita/Desktop/Codex/ai-control-plane/
├── MOBILE-DISPATCH.md             # 3 paths: RC, webhook, ntfy
├── QUICK-MOBILE-SETUP.md          # Filip TL;DR (Mac RC + Flash RC)
├── MULTI-ACCOUNT-WORKFLOW.md      # ← TENTO SOUBOR (handoff)
└── scripts/
    ├── cc-mobile.sh               # Mac RC ad-hoc launcher (ofs mobile)
    ├── flash-rc-setup.sh          # Flash setup orchestrator (--from-mac, --reauth)
    ├── flash-rc-control.sh        # Flash RC control (status/use/save-as/url/...)
    ├── ofs.sh                     # Mac dispatcher (mobile/mobile-flash/...)
    └── lib/claude-rc-flash.service # systemd unit template

Flash:
├── /etc/systemd/system/claude-rc.service       # systemd unit (deployed)
├── /root/.claude/.credentials.json             # active OAuth token (chmod 600)
├── /root/.claude/.claude.json                  # config + oauthAccount cache
├── /root/.claude/creds-backup/                 # per-account snapshots
│   ├── dlouhyphoto.json           # creds
│   ├── dlouhyphoto.oauth.json     # oauthAccount cache
│   └── filipdopit.json            # creds (stale, needs Mac re-login)
├── /root/workspace-rc/                          # RC workspace (spawn=worktree)
└── /var/log/claude-rc.log                       # service log

Mac:
├── ~/.claude/.credentials.json                 # current Mac CLI creds
├── ~/.claude.json                              # global config + oauthAccount
└── ~/Library/Keychains/login.keychain-db       # macOS Keychain
    entry "Claude Code-credentials"             # legacy/secondary token
```

## Kontrola z Macu

```bash
ofs mobile-flash status            # is-active + auth + log tail
ofs mobile-flash logs [N]          # tail logu (default 50)
ofs mobile-flash follow            # tail -f real-time
ofs mobile-flash restart           # restart service
ofs mobile-flash stop / start      # disable / enable
ofs mobile-flash url               # extract session URL z logu
ofs mobile-flash list-accounts     # list backup accounts
ofs mobile-flash use <name>        # switch active account (creds + cache)
ofs mobile-flash save-as <name>    # snapshot current state pod aliasem
ofs mobile-flash from-mac          # SCP current Mac creds → Flash (sync mode)
ofs mobile-flash reauth            # browser flow (--reauth, fallback)

# 2026-05-03 ekosystém + auth automation
ofs mobile-flash sync-ecosystem    # mirror Mac ~/.claude/{rules,knowledge,...} → Flash
ofs mobile-flash ecosystem-info    # show MANIFEST.md + last sync timestamp + size/file counts
ofs mobile-flash check-auth        # detect OAuth expiry + creds age (manual; cron běží 6h)
```

## Multi-account workflow

### Přidat nový Anthropic account do mix (~3 min, jednou per účet)

```bash
# Krok 1: Mac CC switch na cílový account
claude /login                      # vyber requested account, projdi browser autorize

# Krok 2: SCP fresh creds + oauthAccount cache → Flash
ofs mobile-flash from-mac          # =  flash-rc-setup.sh --from-mac
                                   # SCP ~/.claude/.credentials.json + Mac oauthAccount
                                   # restart claude-rc
                                   # verify auth status na Flash

# Krok 3: Snapshot pro budoucí switching bez Mac flow
ofs mobile-flash save-as <name>    # např. save-as filipdopit
                                   # uloží creds + oauth cache do creds-backup/

# Krok 4 (volitelné): Mac vrať na původní account
claude /login                      # zpátky např. dlouhyphoto
```

### Switch mezi backed-up účty (~5s, kdykoliv)

```bash
ofs mobile-flash list-accounts     # ukáž dostupné: dlouhyphoto, filipdopit, ...
ofs mobile-flash use filipdopit    # restore creds + oauthAccount, restart RC
ofs mobile-flash use dlouhyphoto   # zpátky
```

### Stale token recovery

OAuth tokeny expirují (~30-90 dní). Když `ofs mobile-flash use <name>` selže s `email:null orgId:null`:

```bash
# Re-do step 1-3 from "Přidat nový account"
claude /login                      # cílový account
ofs mobile-flash from-mac
ofs mobile-flash save-as <name>    # přepíše stale backup
```

## iOS app pairing

Aby phone session viděla "Filip Flash" v session list, **iOS Claude app MUSÍ být přihlášena pod stejným accountem jako Flash**.

| Flash běží jako | iOS app musí být logged jako |
|---|---|
| dlouhyphoto@gmail.com | dlouhyphoto@gmail.com |
| filipdopit@gmail.com | filipdopit@gmail.com |

Switch iOS account: app → Settings/profile → Sign Out → Sign In jako požadovaný účet.

**Pattern**: Filip pracuje pod různými projekty pod různými accounty. Když chce přepnout phone session:
1. `ofs mobile-flash use <account>` na Mac
2. iOS Claude app: Sign Out → Sign In jako stejný account
3. Session list → "Filip Flash" → tap

## Push notifikace

Po prvním connectu z phone, v RC session spusť:
```
/config
```
→ "Push when Claude decides" → **ON**

Claude pak pingne phone když:
- dlouhý task hotov
- potřebuje rozhodnutí
- explicit `notify me when X` v promptu

## Architektura (proč to funguje)

```
iPhone (Claude iOS app, logged X)
    │ outbound HTTPS POST (zprávy)
    ▼
Anthropic API (TLS, short-lived creds, session router)
    │ relay
    ▼
Flash systemd `claude-rc.service` (logged X — match required)
    │ poll loop (outbound HTTPS only)
    │ Working dir: /root/workspace-rc (spawn=worktree)
    │ ENV CLAUDE_CODE_ADDITIONAL_DIRECTORIES_CLAUDE_MD=/root/.claude-ecosystem (LOCAL mirror, 2026-05-03 lift-shift)
    │   ↳ obsahuje: CLAUDE.md, rules/, knowledge/, expertise/, skills/, agents/, commands/
    │   ↳ synced via cron 00:30 UTC + on-demand `ofs mobile-flash sync-ecosystem`
    │   ↳ fallback dostupný přes /mac (sshfs Mac→Flash) — pro memory/, projects/ které nesync-ujeme
    │ stdin trick: < <(printf "y\n"; sleep infinity) — auto-confirm RC enable
    ▼
Tool execution: Read/Write/Edit/Bash/MCP (lokální Flash workspace + /mac sshfs pro source-of-truth files)
```

**Klíčové triky:**
1. **Workspace trust bypass**: `/root/.claude.json → projects['/root/workspace-rc'].hasTrustDialogAccepted=true`
2. **RC consent prompt bypass**: stdin `printf "y\n"; sleep infinity` v unit ExecStart
3. **OAuth cache invalidation**: pop `oauthAccount` v `/root/.claude.json` když měníme creds → CLI re-fetch
4. **Per-account portability**: creds JSON file (914B, contains accessToken+refreshToken+orgId) je portable Mac↔Flash pokud token NENÍ expired

## Rules dependencies (pro novou Claude session)

Tato session inheritne automaticky všechny tvoje globální rules přes `/mac/.claude/CLAUDE.md` mount:
- TOP RULES: anti-hallucination, completion-mandate, prompt-completeness, hard-stop-zone
- Codex bridge routing
- OneFlow brand voice
- Memory routing (knowledge-router, workflow-routing)
- Cost zero tolerance

## Ekosystém lift-shift na Flash (2026-05-03)

Před: `CLAUDE_CODE_ADDITIONAL_DIRECTORIES_CLAUDE_MD=/mac/.claude` (sshfs mount). Když Mac usnul / WG drop / sshfs unmount → phone session přišla o CLAUDE.md, rules, knowledge, skills.

Po: `CLAUDE_CODE_ADDITIONAL_DIRECTORIES_CLAUDE_MD=/root/.claude-ecosystem` (LOCAL mirror, ~1.1 GB).

### Co se mirroruje

| Adresář | Účel |
|---|---|
| `CLAUDE.md` | TOP RULES + routing pointers |
| `rules/` | anti-hallucination, completion-mandate, hard-stop-zone, context-hygiene, ... |
| `knowledge/` | lazy-rules, code/, sops/, from-lukas-v2/, imported-patterns/ |
| `expertise/` | YAML domain configs (oneflow-brand, agent-employees, prompt-engineering, ...) |
| `skills/` | 336 skills (vyloučeno: cache, models, screenshots, embeddings, runtime artifacts) |
| `agents/` | 55 subagent definitions |
| `commands/` | 191 slash command definitions |

### Co se NEsync-uje (zůstává jen na Macu)

- `memory/` (session-specific, 19+ MB MEMORY.md + 89 orphan project files)
- `projects/` (per-project state)
- `creds-backup/` (creds, NEVER replicate)
- `.credentials.json`, `mcp-keys.env` (creds, NEVER replicate)
- `hooks/` (Mac-specific paths v hooks)
- `settings*.json` (per-host config)
- `audits/`, `logs/`, `cache/`, `file-history/` (runtime/historical data)

Pokud phone session potřebuje memory/ nebo projects/ → fallback přes `/mac/.claude/...` (sshfs mount stále k dispozici).

### Auto-sync mechanism

```bash
# On-demand z Macu
ofs mobile-flash sync-ecosystem               # full mirror (rsync delta, ~5s pro inkrementální change)
ofs mobile-flash sync-ecosystem --dry-run     # preview
ofs mobile-flash ecosystem-info               # show MANIFEST.md + last sync ts

# Cron na Flash (auto)
/etc/cron.d/claude-ecosystem-sync             # daily 00:30 UTC pull (Flash → Mac SSH read-only)
```

### Co dělat když měníš rules/skills na Macu

Změnit → uložit → `ofs mobile-flash sync-ecosystem` → phone session vidí změnu okamžitě (next tool call, kdy se rules znovu načítají).

## iPhone hardening (Filipova manuální akce, MAX security)

Anthropic OAuth je **account-level**, ne device-level. To znamená: kdokoli s heslem k service accountu může přidat svůj iPhone do session listu. Bezpečnost závisí na disciplíně credentials, ne na device pairingu.

### Service account discipline

| Pravidlo | Konkrétně |
|---|---|
| **JEDEN dedicated service account** pro Flash | Default: `dlouhyphoto@gmail.com` (current active, Anthropic Max ověřený). Alternativa: vyhradit `filipdopita@gmail.com` jako primary + použít dlouhyphoto jen pro foto/jiné práce. |
| Heslo nikdy nesdílet s kolegy | Service account credentials = Filip-only. Kolegové si claude /login NA MACU pro **svojí práci v Codex repos** — nikdy `from-mac` na Flash pod jejich credentials. |
| 2FA enforced | Anthropic console → 2FA enable (TOTP authenticator app, ne SMS). |
| Kolegova session ≠ Filipova service session | Když kolega sedne k Macu a /login pod svým účtem, Filip MUSÍ udělat `claude /login` zpátky na service account PŘED dalším `ofs mobile-flash from-mac`. Jinak se Flash auth přepíše na kolegův token. |

### iPhone 15 fyzická vrstva

| Vrstva | Akce |
|---|---|
| iPhone unlock | Face ID + 6-digit PIN (ne 4-digit) |
| Claude iOS app launch | Nastavit Face ID prompt v Settings → Touch ID & Passcode → "Require Face ID" pro Claude app |
| Apple Family / Screen Time | Vytvořit dospělý account JEN pro Filipa, restrict app install pro děti/rodinu pokud sdílí Apple ID |
| Backup iCloud | Zapnutý ✓ ale **bez Claude session export** (Anthropic neukládá session do iCloud) |
| Lost mode | Find My iPhone aktivované — pokud telefon ztracen → remote logout přes claude.ai web (Settings → Sessions → Revoke) |

### Per-iPhone audit (jednou za měsíc)

```bash
# Z Macu
ofs mobile-flash check-auth          # zkontroluj že session běží pod správným accountem
# Pak v claude.ai web (browser na Macu):
# Settings → Sessions → vidíš všechna připojená zařízení
# Pokud vidíš zařízení které není Filipovo → revoke + change password
```

## Auto-renewal & monitoring

### Auth expiry detection

OAuth tokeny expirují za 30-90 dní (closed implementation, neexponuje TTL). Cron na Flash běží 1×/6h:

```bash
/etc/cron.d/claude-flash-auth-check     # 0 */6 * * * → /usr/local/bin/check-flash-auth.sh
```

Co kontroluje:
- `claude auth status` → `loggedIn: true`?
- `systemctl is-active claude-rc` → active?
- `stat -c %Y /root/.claude/.credentials.json` → mtime > 60 dní = preemptive alert

Když fail → ntfy push Filipovi:
```
[Flash Auth Check] HIGH PRIORITY
"Flash auth EXPIRED. Run on Mac: ofs mobile-flash from-mac"
```

### Manual recovery

```bash
# Na Macu, jakmile dostaneš ntfy alert:
claude /login                          # vyber service account, projdi browser flow
ofs mobile-flash from-mac              # SCP fresh creds → Flash, restart RC
ofs mobile-flash status                # verify loggedIn=true + service active
```

### Recovery od koleg-account incidentu

Pokud Filip omylem `from-mac` přes kolegův login (dvojitý sync) → Flash běží pod kolegou → kolega vidí Filipovy session v iOS app.

```bash
# Na Macu Filip:
claude /login                          # zpátky service account (dlouhyphoto)
ofs mobile-flash from-mac              # přepiš Flash creds zpět
# Pak v claude.ai web → Settings → Sessions → revoke kolegovy zařízení
# (kolega už neuvidí Flash session ani když zůstane logged-in jejich účtem)
```

## Známé limitace

| Limit | Workaround |
|---|---|
| OAuth token expiry ~30-90d | Auto-detect cron + ntfy push → `ofs mobile-flash from-mac` (proces ~30s) |
| 1 active session per Flash service | Pro paralelní accounts: `--capacity 8` worktree spawn dovoluje multi sessions per account; pro multi-account naráz potřeba nasadit druhou systemd unit (claude-rc-2.service) — neni teď setup |
| Mac filesystem přes sshfs (latence) | Pro běžné rules/skills → LOCAL `/root/.claude-ecosystem` (žádná latence). Pro memory/projects → fallback `/mac/...` |
| iOS app a Flash MUSÍ matchovat account | `ofs mobile-flash use <name>` + iOS sign-in jako same account |
| RC nepodporuje API key auth | Required: claude.ai OAuth (full-scope) — ne `claude setup-token` |
| /mcp, /plugin, /resume z phone | Local-only commands — TTY required, fungují jen z terminálu |
| Anthropic OAuth = account-level, ne device-level | Security přes 2FA + service account discipline (viz § iPhone hardening) — ne přes Anthropic device pairing (neexistuje) |

## Resume v nové Claude Code session

Pokud budeš pokračovat v této práci v nové session:

```bash
# 1. Načti context
cat ~/Desktop/Codex/ai-control-plane/MULTI-ACCOUNT-WORKFLOW.md
cat ~/Desktop/Codex/ai-control-plane/QUICK-MOBILE-SETUP.md

# 2. Verify live state
ofs mobile-flash status

# 3. Pokud něco selhalo:
ofs mobile-flash logs 100
ofs mobile-flash restart
```

## Co hledat v memory pokud potřebuješ víc

```bash
grep -r "mobile.*RC\|claude-rc\|workspace-rc\|filipdopit\|dlouhyphoto" \
  ~/.claude/projects/-Users-filipdopita-Desktop-Codex/memory/ 2>/dev/null | head -10
```

## TL;DR

- Flash = always-on Claude Code Remote Control server (systemd, Restart=always)
- Active account: dlouhyphoto (filipdopit creds stale, needs Mac re-login)
- iOS app + Flash account musí matchovat
- Multi-account = `creds-backup/` snapshots + `ofs mobile-flash use <name>` switching
- Ekosystém (CLAUDE.md, skills routing, memory) inherited via `/mac/.claude` sshfs mount

Dopita
