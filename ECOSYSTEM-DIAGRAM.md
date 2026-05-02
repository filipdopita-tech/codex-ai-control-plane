# OneFlow / Filip — Ekosystém ke 2026-05-03

> Snapshot živé architektury napříč Mac + 2 VPS + Claude Code harness + Codex bridge + OneFlow services + AI providers + memory/knowledge layer.
> Verified live: skills 293 / agents 57 / hooks 50 / MCPs 14. Flash services: dovecot ✅ postfix ✅ hermes 💤 conductor 💤.

---

## 1) High-level layered view (ASCII)

```
┌──────────────────────────────────────────────────────────────────────────────────────┐
│                           👤 FILIP @ Mac (source of truth)                           │
│                            Terminal · IDE · Browser · Obsidian                       │
└────────┬─────────────────────────────────────────────────────────────┬───────────────┘
         │                                                              │
         ▼                                                              ▼
┌───────────────────────────┐                              ┌─────────────────────────┐
│   🧠 CLAUDE CODE HARNESS   │                              │   📦 CODEX BRIDGE       │
│   (orchestrator + brain)   │ ◀─── delegate-to-codex.sh ──▶│   (impl + repo agent)   │
│                           │                              │                         │
│  Models:                  │                              │  Mode: auto/lean/full   │
│   • Opus 4.7 (architecture│                              │  Scripts:               │
│   • Opus 4.7 1M (mega)    │                              │   • delegate-to-codex   │
│   • Sonnet 4.6 (default)  │                              │   • ask-claude-review   │
│   • Haiku 4.5 (subagents) │                              │   • ask-claude-strategy │
│                           │                              │   • route-task / ofs    │
│  Free fallback (OpenRouter│                              │   • doctor / scan       │
│   → DeepSeek R1, Qwen 3   │                              │   • obsidian-dashboard  │
│     Coder, Kimi K2,       │                              │   • verify-10-10        │
│     Nemotron Nano)        │                              │                         │
│                           │                              │                         │
│  Harness:                 │                              │  HARD-STOP zone honored │
│   • 293 skills            │                              │  (no secrets in handoff)│
│   • 57 agents             │                              └─────────────────────────┘
│   • 50 hooks              │
│   • 14 MCPs               │
│   • Memory + recall       │
└───────────┬───────────────┘
            │
            ▼
┌──────────────────────────────────────────────────────────────────────────────────────┐
│                          🔐 INFRA LAYER (WireGuard 10.77.0.0/24)                     │
│                                                                                      │
│   Mac (10.77.0.2)  ◀───── SSHFS /mac mount ─────▶  Flash VPS (10.77.0.1, 12 GB)     │
│                                                                                      │
│   Source of truth                                  Compute + services                │
│    • ~/Documents                                    • Hermes Agent (💤 inactive)     │
│    • ~/.claude (293 skills)                         • Conductor (💤 inactive)        │
│    • OneFlow-Vault (Obsidian)                       • Dovecot ✅ (mailbox)           │
│    • ~/.credentials                                 • Postfix ✅ (SMTP relay)        │
│                                                     • Scrapers (Apify, Playwright)   │
│                                                     • ntfy.oneflow.cz               │
│                                                     • errors.oneflow.cz (planned)    │
│                                                     • file.oneflow.cz (planned)      │
│                                                                                      │
│                                              Alfa VPS (email + CZ IP relay)         │
│                                                     • Wedos legacy archive           │
│                                                     • SMTP submission backup         │
└──────────────────────────────────────────────────────────────────────────────────────┘
            │
            ▼
┌──────────────────────────────────────────────────────────────────────────────────────┐
│                          🧠 KNOWLEDGE / MEMORY LAYER                                 │
│                                                                                      │
│  Auto-loaded:                       Lazy-loaded (router):           Persistent:      │
│   • CLAUDE.md (TOP RULES)            • knowledge-router.md           • Obsidian Vault│
│   • MEMORY.md (manifest)             • workflow-routing.md            (~/Documents/  │
│   • RTK.md                           • oneflow-all.md                 OneFlow-Vault) │
│   • rules/anti-hallucination         • lean-engine.md                • memory/*.md   │
│   • rules/completion-mandate         • reasoning-depth.md            • graphiti KG   │
│   • rules/prompt-completeness        • codex-bridge-routing.md       • qmd index     │
│   • rules/hard-stop-zone             • cost-zero-tolerance.md         (4GB hybrid    │
│                                                                       BM25+vector)   │
│                                                                                      │
│  Recall cascade: grep MEMORY → memory-search MCP → Obsidian → graphiti              │
└──────────────────────────────────────────────────────────────────────────────────────┘
            │
            ▼
┌──────────────────────────────────────────────────────────────────────────────────────┐
│                          🌐 EXTERNAL TOUCHPOINTS                                     │
│                                                                                      │
│   Send:                          Read:                       Compute/AI:             │
│    • Email (dopita@oneflow.cz)   • ARES (free CZ company)    • Anthropic API         │
│    • ntfy push (Filip)           • Apollo (deprecated post   • OpenRouter (free)     │
│    • WhatsApp (READ-ONLY)          2026-09 — use direct)     • fal.ai (image)        │
│    • LinkedIn (Voyager)          • Apify (public scrape)     • Kie.ai (image, free)  │
│    • Slack/Telegram (Hermes)     • Hunter.io (email verify)  • OpenAlex/arxiv        │
│                                  • CrUX/GSC/GA4 (Google      • NotebookLM (research) │
│   🛑 BLOCKED (cost-zero):         OAuth — free quota)         • HuggingFace          │
│    • Google Solar / Maps                                                             │
│    • Vertex / Gemini paid                                                            │
│    • Gemini API (any tier)                                                           │
└──────────────────────────────────────────────────────────────────────────────────────┘
```

---

## 2) Mermaid flowchart (renderable v Obsidian / GitHub / Mermaid Live)

```mermaid
flowchart TB
    subgraph USER["👤 Filip @ Mac"]
        TERM[Terminal / IDE / Browser]
    end

    subgraph BRAINS["🧠 AI Brains"]
        CC["Claude Code<br/>Opus 4.7 / Sonnet 4.6 / Haiku 4.5<br/>+ 1M context variant"]
        CODEX["Codex Agent<br/>(impl / repo work)"]
        OR["OpenRouter Free<br/>DeepSeek R1 / Qwen 3 / Kimi K2"]
    end

    subgraph HARNESS["⚙️ Claude Harness"]
        SK["293 Skills<br/>(GSD, SEO, content,<br/>marketing, design,<br/>research, finance...)"]
        AG["57 Agents<br/>(orchestrator, code-reviewer,<br/>seo-*, eng-director,<br/>shannon-pentester...)"]
        HK["50 Hooks<br/>(autonomy-guard,<br/>google-api-guard,<br/>completion-mandate...)"]
        MCP["14 MCPs<br/>(context7, time, obsidian,<br/>filesystem, code-review-graph,<br/>memory-search, stitch...)"]
        MEM["Memory Layer<br/>MEMORY.md manifest +<br/>recall cascade"]
    end

    subgraph INFRA["🔐 Infra (WireGuard 10.77.0.0/24)"]
        MAC["Mac<br/>10.77.0.2<br/>Source of truth"]
        FLASH["Flash VPS<br/>10.77.0.1 · 12GB<br/>Compute + services"]
        ALFA["Alfa VPS<br/>Email relay + CZ IP"]
    end

    subgraph SVC["🚀 OneFlow Services"]
        EMAIL["📬 Email<br/>dopita@oneflow.cz<br/>Dovecot ✅ Postfix ✅"]
        HERMES["🤖 Hermes Agent<br/>(💤 inactive)<br/>Multi-platform gateway"]
        CONDUCTOR["🎼 Conductor<br/>(💤 inactive)<br/>Workflow orchestration"]
        SCRAPE["🕷️ Scrapers<br/>ARES / Apollo / Apify<br/>Playwright"]
        NTFY["📡 ntfy.oneflow.cz<br/>Push notifications"]
        WEB["🌐 oneflow.cz<br/>Landing + content"]
    end

    subgraph KNOW["📚 Knowledge Layer"]
        VAULT["Obsidian Vault<br/>~/Documents/OneFlow-Vault<br/>Wiki + raw + daily"]
        QMD["qmd index<br/>4GB hybrid<br/>BM25 + vector + LLM"]
        GRAPH["Graphiti KG<br/>(temporal)"]
        OBSIDIAN_MCP["Obsidian MCP<br/>(read/write notes)"]
    end

    subgraph EXT["🌍 External"]
        ANTHROPIC["Anthropic API<br/>(Max 20x sub)"]
        FAL["fal.ai / Kie.ai<br/>Image gen"]
        APIFY["Apify / Hunter<br/>Scraping + verify"]
        ARES["ARES (CZ)<br/>Free company data"]
        GMAIL["Gmail/Drive/Calendar<br/>OAuth (free quota)"]
        BLOCKED["🛑 BLOCKED<br/>Google paid APIs<br/>Vertex / Gemini / Solar / Maps"]
    end

    TERM --> CC
    CC <-->|"delegate-to-codex.sh<br/>ask-claude-review.sh"| CODEX
    CC -.->|free fallback<br/>1500 req/day| OR

    CC --> SK
    CC --> AG
    CC --> HK
    CC --> MCP
    CC --> MEM

    SK -.->|lazy-load via router| KNOW
    MCP -.-> OBSIDIAN_MCP
    OBSIDIAN_MCP --> VAULT
    MEM --> QMD
    MEM --> GRAPH

    MAC <-->|"SSHFS /mac mount<br/>WireGuard"| FLASH
    MAC <-->|WG| ALFA
    FLASH <-->|SMTP relay| ALFA

    CC --> MAC
    CODEX --> MAC

    FLASH --> EMAIL
    FLASH --> HERMES
    FLASH --> CONDUCTOR
    FLASH --> SCRAPE
    FLASH --> NTFY
    MAC --> WEB

    SCRAPE -.-> APIFY
    SCRAPE -.-> ARES
    EMAIL -.->|sends only with<br/>explicit Filip approval| BLOCKED
    CC -.->|hooks block| BLOCKED
    CC -.-> ANTHROPIC
    CC -.-> FAL
    CC -.-> GMAIL

    classDef inactive fill:#3a3a3a,stroke:#888,color:#aaa,stroke-dasharray: 5 5
    classDef blocked fill:#3a1a1a,stroke:#a44,color:#faa
    classDef active fill:#1a3a1a,stroke:#4a4,color:#afa
    class HERMES,CONDUCTOR inactive
    class BLOCKED blocked
    class EMAIL,DOVECOT,POSTFIX active
```

---

## 3) Critical paths (jak co teče)

| Use case | Path |
|---|---|
| **Filip zadá impl task** | Filip → Claude Code → `delegate-to-codex.sh` → Codex → soubory v repu → (optional) `ask-claude-review.sh` → Claude review → commit |
| **Filip zadá strategy/text task** | Filip → Claude Code (přímo, bez Codexu) → output |
| **Recall ("co jsem řešil X")** | Claude → grep MEMORY.md → memory-search MCP → Obsidian search → graphiti KG |
| **DD report / klientský deliverable** | Claude → /evalopt loop (Gemini→OpenRouter free, ≥85 score) → Filip approval → ship |
| **Cold email / outreach** | Claude → `outreach-oneflow` skill → 9-bod pre-send checklist → Filip approval → Postfix Flash → recipient |
| **Lead enrichment** | Claude → ARES (CZ free) + Hunter (verify) + Apollo direct (deprecated post 2026-09 → migrate) → CRM/Sheets |
| **Content (IG carousel/reel)** | Claude → `ig-content-creator` skill → /evalopt brand voice → huashu-design hi-fi → publish |
| **Pentest / security audit** | Claude → `shannon` skill → Flash VPS → exploit attempts → blue-team auto-chain → audit verdict |
| **Vault search** | Claude → `qmd` skill (CLI) → 4GB hybrid index → BM25 + vector + LLM rerank |
| **External AI watchlist** | Claude → `ai-radar --scope=external` → cherry-pick → MEMORY append → /apply-improvements |

---

## 4) Hard-stop zóna (jediné domény, kde Claude se ptá)

1. **Platby / cost generation** → cost-zero-tolerance.md (Google paid APIs = HARD BAN po 2026-04-27)
2. **Odeslání zpráv** → email/WA/SMS/Slack/Telegram/LinkedIn (READ-ONLY default)
3. **Nevratná destrukce** → DROP, force push main, rm -rf prod
4. **FB/Meta login** → fb-scrape-safety.md (Tier 1 alternativy = auto-allow)
5. **Strategy >100k Kč / legal binding** → CNB filing, hire/fire, equity changes

Vše ostatní = Claude rozhodne sám → dokončí → reportuje.

---

## 5) Provozní stav (live snapshot)

| Komponenta | Stav | Pozn. |
|---|---|---|
| Mac harness (skills/agents/hooks/MCPs) | ✅ 293 / 57 / 50 / 14 | W7 closure 2026-05-03 |
| Flash dovecot | ✅ active | mailbox dopita@oneflow.cz |
| Flash postfix | ✅ active | SMTP relay |
| Flash hermes | 💤 inactive | installed, není auto-start |
| Flash conductor | 💤 inactive | workflow orchestrace, pause |
| Codex bridge | ✅ 18 scripts | delegate / review / strategy / ofs |
| Memory layer | ✅ 10 entries | post-W7 manifest |
| Audit health | 🟢 HEALTHY | 2026-05-03 první 0 warnings |
| Anthropic SDK upgrade 0.87→0.97 | ✅ done | Managed Agents Memory ready |
| Gemini ban | 🛑 enforced | hook v3 + sandbox + cron disabled |

---

## 6) Známé gaps / next moves

- 💤 **Hermes** + **Conductor** inactive → rozhodnout: enable on boot vs. retire
- 📦 **Beads / chibisafe / GlitchTip** = SHOULD CONSIDER, neinstalováno
- 🔄 **Apollo deprecation 2026-09** → migrate na direct Apollo official scraper paid (cost approval needed)
- 📊 **errors.oneflow.cz** (GlitchTip) + **file.oneflow.cz** (chibisafe) = planned subdomény, neexistují
- 🧪 **Managed Agents Memory v0.97** = ready, eval jako Conductor replacement Q3 2026

---

*Generated 2026-05-03 · Source: live filesystem + MEMORY.md + audit history*
*Update cmd: `/audit-system` (full scan) or refresh manually after major topology change.*
