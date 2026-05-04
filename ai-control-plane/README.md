# AI Control Plane

Centrální vrstva pro spolupráci mezi Codexem, Claude Code, VS Code, Macem, VPS a cloudovými konektory.

## Základní idea

Nepouštět dvě AI do nekonečné debaty. Používat je jako dvě role nad stejným zdrojem pravdy:

- Claude Code = stratég, plánovač, kritik zadání, dlouhý kontext.
- Codex = implementátor, refaktor, test runner, repo agent, matematika a technická přesnost.
- Git/workspace = zdroj pravdy.
- `ai-handoffs/` = auditovatelná fronta úkolů mezi AI.

## Doporučený model

1. Člověk nebo Claude popíše cíl.
2. Handoff skript vytvoří strukturovaný úkol.
3. Codex dostane přesné zadání proti jednomu projektu.
4. Codex upraví soubory, spustí testy a zapíše výsledek.
5. Claude může výsledek zkontrolovat jako reviewer/strateg.

## Bezpečnostní pravidla

- Každý úkol má mít konkrétní projekt a očekávaný výstup.
- AI-to-AI volání používat na omezené úkoly, ne jako permanentní smyčku.
- Secrets se nepřenášejí v handoff souborech.
- Produkční cloud/VPS změny mají projít healthcheckem nebo ručním potvrzením.

## Hlavní příkazy

```bash
# Diagnostika a údržba
./ai-control-plane/scripts/scan.sh                        # rychlý discovery
./ai-control-plane/scripts/doctor.sh                      # plná diagnostika
./ai-control-plane/scripts/control-plane-optimize.sh       # safe daily optimizer
./ai-control-plane/scripts/mcp-process-cleanup.sh          # dry-run stale MCP cleanup
./ai-control-plane/scripts/update-core.sh                 # gcloud/VS Code/brew upgrade + doctor
./ai-control-plane/scripts/test-bridge.sh                 # end-to-end smoke test (Codex + Claude)
./ai-control-plane/scripts/cleanup-handoffs.sh --dry-run  # rotace audit logu

# Bridge: Claude -> Codex
./ai-control-plane/scripts/delegate-to-codex.sh /path/to/project "úkol"

# Bridge: po Codexu zpátky na Claude review
./ai-control-plane/scripts/ask-claude-review.sh /path/to/project "review otázka"

# Bridge: strategická otázka do Claude bez implementačního běhu
./ai-control-plane/scripts/ask-claude-strategy.sh /path/to/project "strategická otázka"

# Router: automaticky vybere Codex lean/full nebo Claude gate
./ai-control-plane/scripts/route-task.sh /path/to/project "volně popsaný úkol"
./ai-control-plane/scripts/route-task.sh --dry-run /path/to/project "jen ukaž trasu"

# Ruční tvorba handoffu (bez execute)
./ai-control-plane/scripts/handoff.sh codex|claude /path/to/project "zadání"
```

Každý skript má `--help`.

`doctor.sh` je hlavní ověřovací příkaz. Kontroluje Codex, Claude Code, Google Cloud SDK, VS Code rozšíření, MCP/plugin signály a dostupné updaty.

## Routing decision tree

```text
Úkol vyžaduje editaci souborů, refaktor, testy, build?
  ├─ ANO  -> delegate-to-codex.sh
  └─ NE
      ├─ Strategie, copywriting, dlouhý kontext, analýza?
      │   -> Claude přímo (žádný bridge)
      └─ Risk změna od Codexu, deploy gate, security?
          -> ask-claude-review.sh

Cost rules:
  - Triviální chat / mikroověření -> Claude přímo
  - Standardní implementace -> AI_BRIDGE_CODEX_MODE=lean (default)
  - Google/MCP/browser/plugin task -> AI_BRIDGE_CODEX_MODE=full
  - Nikdy: review po každé malé změně
  - Nikdy: secrets v handoff promptu
  - Nikdy: delegace bez konkrétního projektu, ověření a koncového reportu
  - Pokud nejde něco ověřit, výstup musí být označen jako neověřený včetně důvodu
```

Praktický vstupní bod pro tento strom je `route-task.sh`. Ten vezme volný task,
načte projektový profil z `projects.json`, vytvoří audit routing rozhodnutí,
vybere trasu, vypíše důvod rozhodnutí a potom zavolá existující bridge:

- lokální diagnostika / údržba -> `doctor.sh` nebo `update-core.sh`
- implementace, refaktor, testy, build, skripty -> Codex lean
- implementace s Google/MCP/browser/cloud/tooling kontextem -> Codex full
- riziková implementace -> Codex a následně Claude review
- review, security, deploy, production, VPS, secrets, approval -> Claude gate
- strategie, architektura, roadmapa, vysvětlení bez editace -> Claude strategy

`update-core.sh` je top-tier update workflow pro jádro AI pracovního prostředí: Google Cloud SDK komponenty, VS Code AI/cloud rozšíření, plný `brew upgrade --greedy`, `brew autoremove`, cleanup a následný doctor report.

Bezpečné režimy:

```bash
./ai-control-plane/scripts/control-plane-optimize.sh       # denní health/pressure/MCP/handoff pass
./ai-control-plane/scripts/control-plane-optimize.sh --fast # bez pomalejších update signalů
./ai-control-plane/scripts/mcp-process-cleanup.sh          # ukaž stale duplicate MCP procesy
./ai-control-plane/scripts/mcp-process-cleanup.sh --apply --kind code-review-graph
./ai-control-plane/scripts/update-core.sh --dry-run     # ukaž kroky bez změn
./ai-control-plane/scripts/update-core.sh --check-only  # update signály + doctor bez upgradu
./ai-control-plane/scripts/update-core.sh               # aplikuj update workflow
```

Automatizace: týdenní `launchd` job `com.filipdopita.ai-core-update` spouští `update-core.sh` každou sobotu v 04:15. Logy jsou v `~/Library/Logs/ai-control-plane/update-core.log` a `~/Library/Logs/ai-control-plane/update-core.err.log`.

`delegate-to-codex.sh` má cost-aware režimy:

- `auto` default: běžný kód jede lean, cloud/plugin úlohy full
- `lean`: ignoruje uživatelskou Codex konfiguraci, kde to CLI dovolí
- `full`: načte plnou Codex konfiguraci s MCP/pluginy

Poznámka: Codex CLI má i v lean režimu startovací overhead. Pro drobné otázky a mikro-úkoly je levnější použít Claude přímo. Codex bridge se vyplatí hlavně pro skutečnou práci v souborech, testy, refaktor a implementaci.

Příklad:

```bash
AI_BRIDGE_CODEX_MODE=full ./ai-control-plane/scripts/delegate-to-codex.sh /path/to/project "úkol s Google Drive nebo browserem"
```

## Co už je v systému

- Codex CLI: `codex exec`
- Claude Code CLI: `claude -p`
- VS Code CLI: `code`
- Codex pluginy: Gmail, Google Drive, Calendar, browser, docs, sheets, slides
- Claude MCP vrstva: GitHub, Gmail, Playwright, memory, VPS/Graphiti a další
