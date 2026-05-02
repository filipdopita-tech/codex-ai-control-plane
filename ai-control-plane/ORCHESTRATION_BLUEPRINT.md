# Orchestration Blueprint

## Cíl

Postavit z Codexu a Claude Code jeden praktický pracovní systém:

- Claude Code navrhuje, třídí, kontroluje a drží kontext.
- Codex provádí technické změny v projektech.
- VS Code je hlavní pracovní plocha.
- Mac drží lokální nástroje, credentials a healthchecky.
- VPS/cloud je výkonná nebo integrační vrstva.

## Architektura

```text
User
  |
  v
route-task.sh / routing layer
  |
  | codex lean/full OR claude review/strategy
  v
Claude Code / strategy layer
  |
  | structured handoff when needed
  v
ai-control-plane / handoff files
  |
  v
Codex / implementation layer
  |
  v
Project repo + tests + git diff
  |
  v
Claude/Codex review + deploy decision
```

## Konkrétní napojení Claude -> Codex

Primární vstupní bod pro volně popsané úkoly:

```bash
./ai-control-plane/scripts/route-task.sh /path/to/project "úkol"
```

Router používá konzervativní scoring podle signálů v tasku a profilu projektu:

- lokální diagnostika/údržba -> doctor/update-core bez AI běhu
- editace/testy/build/refaktor -> Codex lean
- Google/MCP/browser/cloud/tooling -> Codex full
- riziková implementace -> Codex a potom Claude review
- deploy/security/produkce/VPS/secrets/review -> Claude gate
- strategie/architektura/roadmapa/vysvětlení -> Claude strategy

Každé rozhodnutí zapisuje audit soubor do `ai-control-plane/handoffs/`.

Pro kontrolu bez spuštění:

```bash
./ai-control-plane/scripts/route-task.sh --dry-run /path/to/project "úkol"
```

Claude může přes Bash spustit:

```bash
codex exec --cd "$PROJECT" --sandbox workspace-write --skip-git-repo-check "$PROMPT"
```

Používat pro:

- opravy bugů
- refaktoring
- testy
- vytvoření skriptů
- audit konkrétního repozitáře

Nepoužívat pro:

- nekonečné auto-loop úlohy
- masivní zásahy napříč všemi projekty bez registru
- operace se secrets v promptu

## Konkrétní napojení Codex -> Claude

Codex může přes Bash spustit:

```bash
claude -p --model sonnet "$PROMPT"
```

Používat pro:

- druhý názor na architekturu
- review diffu
- formulaci roadmapy
- práci s pravidly v Claude ekosystému

## Doporučené role

| Vrstva | Primární nástroj | Úloha |
|---|---|---|
| Strategická | Claude Code | plán, priorita, rozhodnutí |
| Implementační | Codex | kód, testy, soubory |
| Review | Claude + Codex review | rizika, regresní testy |
| Knowledge | Obsidian/Drive/Graphiti | dlouhodobá paměť |
| Cloud/VPS | skripty + MCP | běhy, integrace, služby |

## Fáze zavedení

### Fáze 1: Stabilizace

- Udržet `PATH`, CLI a VS Code zdravé.
- Používat `ai-healthcheck.sh`.
- Vytvořit registry hlavních projektů.

### Fáze 2: Handoff protokol

- Každý AI úkol ukládat do `ai-control-plane/handoffs/`.
- Každý výsledek ukládat do stejného souboru nebo vedlejšího `*.result.md`.

### Fáze 3: Projektové profily

- Pro každý důležitý projekt vytvořit:
  - `CLAUDE.md` pro strategii a pravidla.
  - `AGENTS.md` nebo `CODEX.md` pro implementační pravidla.
  - standardní test příkaz.

### Fáze 4: Cloud orchestrace

- Přidat whitelist projektů, které může Codex upravovat automaticky.
- Přidat zvláštní režim pro VPS/cloud deploy: plan -> dry run -> approval -> apply.

## Nejlepší praktický vzor promptu

```text
Jsi implementační agent pro tento projekt.

Cíl:
...

Omezení:
- nejdřív si přečti relevantní soubory
- měň jen soubory nutné pro úkol
- nesahej na secrets
- spusť dostupné testy nebo healthcheck

Výstup:
- co jsi změnil
- kde jsi to změnil
- jak jsi to ověřil
- co zůstává jako riziko
```
