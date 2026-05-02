# AI Ecosystem: Codex + Claude Code

## Stav nastaveni

- Codex workspace: `/Users/filipdopita/Desktop/Codex`
- Codex config: `~/.codex/config.toml`
- Claude config: `~/.claude` a `~/.claude.json`
- VS Code CLI: `code`
- Login shell PATH opraven v `~/.zprofile`

## Role jednotlivych AI

### Claude Code

Pouzivej ho hlavne jako strategickou a ridici vrstvu:

- rozpad velkych napadu na kroky
- produktove a architektonicke uvazovani
- prace s dlouhym kontextem a rozhodovanim
- priprava presneho zadani pro implementaci

### Codex

Pouzivej ho jako vykonnou vyvojarskou vrstvu:

- cteni a upravy souboru v repozitari
- refaktoring, debugging, testy
- frontend a backend implementace
- terminalove prikazy, skripty, lokalni overeni
- matematika, algoritmy, technicka analyza

## Doporučeny tok prace

1. V Claude Code si ujasni cil.
2. Nech si z toho udelat konkretni implementacni zadani.
3. Zadani posli Codexu ve stylu:

   ```text
   Uprav tento projekt podle zadani nize. Nejdriv si precti kod, pak proved zmeny,
   spust dostupne testy a na konci shrn, co se zmenilo.

   Zadani:
   ...
   ```

4. Codex provede zmeny primo v projektu.
5. Vysledek se da znovu zkontrolovat v Claude Code, pokud chces druhy pohled.

## Prakticke pravidlo

- Claude Code = premysleni, strategie, smer.
- Codex = provedeni, kontrola, technicka presnost.
- Git/repozitar = spolecny zdroj pravdy.

## Control plane

Konkretni napojeni Codexu a Claude Code je pripravene v:

- `ai-control-plane/README.md`
- `ai-control-plane/ORCHESTRATION_BLUEPRINT.md`
- `ai-control-plane/projects.json`
- `ai-control-plane/scripts/`

Nejdulezitejsi prikazy:

```bash
./ai-control-plane/scripts/scan.sh
./ai-control-plane/scripts/handoff.sh codex /path/to/project "ukol"
./ai-control-plane/scripts/delegate-to-codex.sh /path/to/project "implementacni ukol"
./ai-control-plane/scripts/ask-claude-review.sh /path/to/project "review nebo strategicka otazka"
```

## Kdy pouzit Codex primo

- "Oprav bug."
- "Najdi, proc pada test."
- "Refaktoruj tuhle cast."
- "Postav UI podle tohohle popisu."
- "Projdi repozitar a navrhni zlepseni."
- "Spust testy a rekni, co je rozbite."

## Kdy pouzit Claude Code jako prvni

- "Nevim, jak to cele navrhnout."
- "Chci roadmapu."
- "Potrebuju rozhodnout mezi variantami."
- "Chci z toho udelat systemovy workflow."
- "Chci promyslet cely ekosystem."
