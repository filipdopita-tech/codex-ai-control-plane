# Mac swap pressure report (2026-05-02 20:42)

## Stav (verified)
- Total swap: 9216 MB
- Used swap: 8110 MB (**88%**)
- Free swap: 1106 MB
- PhysMem: 7458M used / 7632M total (~98%)
- Load avg: 6.87 / 8.47 / 9.18 (na 8-core Mac = >100% load)
- Swapins: 2,461,877 — totální swapping
- `kern.memorystatus_level: 40` (jellyfish-warning level)

## Root cause: cumulative app pressure na 8GB RAM Macu

Top RAM consumers (RSS, dle real top -o rsize):

| Rank | Proces | RSS | Pozn |
|---|---|---|---|
| 1 | com.apple.Virtualization XPC | 1473M (1885M compressed) | macOS system, nelze zabít |
| 2 | Code Helper (Plugin) | 840M | VS Code extension host |
| 3 | Claude Helper (Renderer) | 577M | Claude desktop app |
| 4 | Claude (main) | 550M | Claude desktop app |
| 5 | com.apple.WebKit | 481M | Safari/WebKit |
| 6 | WindowServer | 470M | macOS system |
| 7 | Code Helper (Plugin #2) | 449M | druhý extension host |
| 8 | Codex Helper (Renderer) | 335M | Codex CLI/desktop |
| 9 | Safari | 333M | browser |
| 10 | Code Helper (Plugin #3) | 322M | třetí extension host |
| 11 | Spotify Helper | 300M | hudba |
| 12-15 | 4× claude (background CLI) | 250-263M each | **multiple Claude Code CLI instances** |

Top CPU consumers:
- com.apple.MediaService (iCloud sync) — 52.7% CPU (dlouhotrvající sync)
- FileProvider — 41.6% CPU (Drive/Dropbox/iCloud file sync)
- CoreServices — 22.1% CPU
- claude (main) — 10.1% CPU

## Suma
**Claude/Code/Codex stack:** ~4.0 GB
**macOS system services:** ~2.5 GB
**Browsers + Spotify:** ~600 MB
**Total:** ~7.1 GB (vyprší 8GB physical, jdeme do swap)

= Filip má pravdu. **Default architektura (12 oken Claude Code lokálně) NIKDY nebude fit na 8GB Mac.**

## Rychlé úlevy (≤5 min, reverzibilní)

1. **Quit Spotify** (300MB free) — pokud neslouchá teď
2. **Quit nepouzívané VS Code projekty** — každý Code Helper = 322-840MB
3. **Restart Claude desktop app** — 1.1GB cumulated, restart uvolní fragmentaci
4. **Quit Safari** (333MB) — nebo zavřít taby
5. **Pause iCloud sync** dočasně (52% CPU spike) — System Settings → Apple ID → iCloud → Pause

Po těchto krocích: ~2GB RAM volných, swap pressure poleví během 60-120s.

## Long-term architektura (toto budu stavět ve Wave 1-7)

### Princip
**Mac = lightweight terminal. VPS Flash (12GB RAM) = engine. Telefon = mobile entry.**

### Co by mělo NIKDY běžet na Macu
- ❌ Heavy scraping (1000+ profilů)
- ❌ Bulk DD na 50+ emitentů
- ❌ Image generation batches
- ❌ Multi-hour Claude Code sessions s `/godmode`
- ❌ Mutagen sync agents pro 100k+ souborů
- ❌ Cron heavy tasks (graphify, learning pipeline) — pokud lze přesunout

### Co JE OK na Macu
- ✅ Claude Code v VS Code (1-2 paralelní okna max)
- ✅ Quick chat / brainstorm / strategy
- ✅ VS Code editing (lokální projekty)
- ✅ Recon tasks (krátké, ad-hoc)
- ✅ Browser pro Obsidian / Notion / web tools
- ✅ iMessage, Slack desktop

### Auto-route logic (Wave 3)
Resource monitor cron 5min: pokud
- Mac swap > 80%
- NEBO load > 8
- NEBO PhysMem free < 500MB

→ `ofs route <task>` automaticky zvolí VPS path místo lokální Claude session.

## Action items pro Filipa (manuální, nelze automatizovat bezpečně)

| # | Akce | Dopad | Risk |
|---|---|---|---|
| 1 | Quit nepoužívaná Cursor/VS Code okna (max 1-2 active) | -1.5GB RAM | Žádný |
| 2 | Quit Spotify když nehraje | -300MB | Žádný |
| 3 | Po VPS recovery: heavy tasks ssh do Flash, ne lokálně | -2-3GB v běžném dni | Žádný |
| 4 | Pokud Filip má víc než 2 Claude Code sessions → close staré | -250-577MB každý | Žádný |
| 5 | iCloud sync — počkat na dokončení velkého syncu, pak normalize | dočasné, sám se vyřeší | Žádný |

## Co automatizuji ve Wave 3

`ofs mac-load` → status (RAM%, swap%, load, top consumers) v 5 řádcích
`ofs auto-route <task>` → pokud Mac přetížený, automaticky delegate na VPS místo lokální session
ntfy alert když Mac swap > 90% (nový mega-pressure threshold)
