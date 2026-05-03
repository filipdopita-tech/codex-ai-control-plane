# IMPLEMENTATION HANDOFF — OneFlow + CIAD next 90 days
**Vytvořeno:** 2026-05-03
**Pro:** Novou Claude Code session (fresh context)
**Předpoklad:** Source briefy v `~/Desktop/Codex/research-briefings/2026-05-03/` (INDEX.md + 3 deep)
**Audit:** Po každé akci update tento soubor + memory entry

---

## JAK POUŽÍT TENTO SOUBOR

1. **Otevři novou Claude Code session** (`claude` v terminále nebo VSCode extension)
2. **Pokud Claude má fresh context:** paste do prvního promptu:
   > "Načti `~/Desktop/Codex/research-briefings/2026-05-03/IMPLEMENTATION.md` a `~/Desktop/Codex/research-briefings/2026-05-03/INDEX.md`. Pak začni s prioritou P1 podle stavu níže."
3. **Pro každou akci:** v sekci "Implementační prompty" jsou copy-paste prompty pro Claude. Spusti, dokončí, update status v této tabulce.
4. **Status legend:** `[ ]` not started · `[~]` in progress · `[x]` done · `[!]` blocked

---

## STATUS DASHBOARD

| Priority | Akce | Business | Status | Deadline | Owner |
|---|---|---|---|---|---|
| P1 | ECSP compliance gap analysis OneFlow | OneFlow | [~] | T+14 dní | Claude + Filip |
| P1 | CIAD Manifest v1.0 draft | CIAD | [ ] | T+14 dní | Claude (ghostwriter) + Filip |
| P1 | Personal brand pivot prompt + 3 keynote applications | Cross | [ ] | T+10 dní | Claude + Filip |
| P2 | First CIAD paper "Mech Interp for Policy Makers" outline + draft | CIAD | [ ] | T+30 dní | Claude (research+draft) + Filip (review) |
| P2 | Advisory board candidate outreach (3 leads) | CIAD | [ ] | T+21 dní | Filip (warm intros) |
| P2 | OneFlow podcast pilot — 3 episode outlines + 1 recording | OneFlow | [ ] | T+30 dní | Filip + Claude (briefs) |
| P3 | "ECSP Masterclass" content series (5 IG/LinkedIn pieces) | OneFlow | [ ] | T+45 dní | Claude (drafts) |
| P3 | Green Bond pilot scoping (1 emitent target) | OneFlow | [ ] | T+45 dní | Filip |
| P3 | Symposium 2027 venue + date lock | CIAD | [ ] | T+60 dní | Filip |
| P4 | EU Horizon Europe application Q1 2027 prep | CIAD | [ ] | T+90 dní | Filip + Claude (research) |
| P4 | Bank distribution partnership outreach (KB / ČSOB) | OneFlow | [ ] | T+75 dní | Filip |

---

## P1 — IMPLEMENTAČNÍ PROMPTY

### P1.1 — ECSP Compliance Gap Analysis OneFlow

**Cíl:** Zjistit kde aktuálně OneFlow stojí vůči ECSP requirements (květen 2026 enforcement window) + akční checklist co musí být done před emitenta onboardingem.

**Copy-paste prompt pro novou session:**
```
Spustí ECSP compliance gap analysis pro OneFlow.

Kontext:
- OneFlow = CZ investiční ekosystem (oneflow.cz), retail dluhopisy + fundraising
- EU Crowdfunding Service Provider Regulation (ECSP) = enforcement květen 2026
- Filip (founder) potřebuje vědět: kde jsme vs requirements + jaký je 30-day plan na compliance

Úkoly:
1. WebFetch ESMA ECSP guidance (Q1 2026) + CNB licenční pathway (verifikuj URL přes WebSearch nejdřív)
2. Mapuj 8 kompliančních pillars: AML/KYC, prospekt/disclosures, audit (>1M EUR), GDPR, regulátor reporting, cybersecurity, investor protection, marketing communications
3. Per pillar: current state OneFlow (zjisti grep oneflow-claude-project/ + ssh root@10.77.0.1 kontrola služeb) + gap + akce + cost estimate (EUR)
4. Output: `~/Desktop/Codex/research-briefings/2026-05-03/ECSP-GAP-ANALYSIS.md` s tabulkou + 30-day plan

Anti-hallucination: confidence markery, žádné smyšlené paragraph numbers ECSP regulation.
Stakes: HIGH — od ECSP záleží OneFlow Q3-Q4 revenue.
Reasoning depth > brevity.

Výstup: 2-3 stránky s actionable checklistem. Po dokončení update IMPLEMENTATION.md status na [~] s mým reportem.
```

**Expected output:** ECSP-GAP-ANALYSIS.md (~3-5K, max 2 stránky tabulkou + 30-day plan)
**Tools:** WebFetch, WebSearch, Bash (ssh kontrola), Read (oneflow-claude-project/)
**Verify before done:** Tabulka 8 pillars × 4 columns vyplněna, žádný [UNCERTAIN] na critical pillar bez fallback akce, 30-day plan má dates a ownership.

---

### P1.2 — CIAD Manifest v1.0 Draft

**Cíl:** První publishable asset CIAD — positioning paper "Proč CIAD existuje a co dělá v EU AI safety landscape". 250-500 slov hlavní text + 1-stránkový extended summary.

**Copy-paste prompt:**
```
Drafti CIAD Manifest v1.0 jako foundational positioning asset.

Kontext:
- CIAD = Český institut pro AI a data, ústav (post-NOZ 2014)
- Brand: 70% Anthropic (warm scholarly) + 30% OpenAI (single brand element)
- Doména ciad.cz LIVE
- Reference brief: ~/Desktop/Codex/research-briefings/2026-05-03/ciad-industry-deep.md
- Brand brief: ~/.claude/projects/-Users-filipdopita/memory/project_ciad_brand_brief_2026_04_29.md

Manifest struktura (final cca 500 slov main + 1500 word extended):
1. Otevírací parágraf (2-3 věty) — proč CIAD VZNIKL teď, ne před 5 roky
2. 3 pilíře (AI bezpečnost, data policy, AI etika) — 1 odstavec each, anti-doom anti-hype calibrated
3. V4 perspektiva — proč je nezávislý CZ hlas potřebný v EU AI policy
4. Co CIAD dělá (papers, briefs, symposium, advisory) vs co NEDĚLÁ (komerční konzultace, lobbing, partisan policy)
5. Closing: open invitation pro researchers, policy makers, supporters

Voice: scholarly long-form, žádný marketing tone, žádné em-dashes, žádné banned words (viz ~/.claude/rules/oneflow-all.md), CZ primárně + EN translation v sekundárním souboru.

Output 2 souborů:
- `~/Desktop/Codex/research-briefings/2026-05-03/CIAD-MANIFEST-v1.0-CZ.md`
- `~/Desktop/Codex/research-briefings/2026-05-03/CIAD-MANIFEST-v1.0-EN.md`

Po draftu: spusti /evalopt s rubric (anti-hype, scholarly tone, calibrated, CZ voice, žádné banned words, min score 88).

Verify before done: Žádné [GUESS] o specific researchers/papers/funding amounts (konkrétní data uveď jen [VERIFIED]). Filip review pokyny ve final commentu.
```

**Expected output:** CIAD-MANIFEST-v1.0-CZ.md + EN.md (~3K each)
**Tools:** Read (briefy + brand memory + oneflow-all rules), Write
**Skills:** /evalopt (auto-trigger), prompt-master pokud copy struggle
**Verify before done:** Manifest má 5 sekcí, voice check passed, /evalopt score ≥85.

---

### P1.3 — Personal Brand Pivot Setup

**Cíl:** Filip má lockenutý positioning + 3 keynote application drafts + LinkedIn bio update + content pillar plán.

**Copy-paste prompt:**
```
Setup Filip personal brand pivot na "Post-Communist Founder Who Built AI-First Finance".

Kontext:
- Reference: ~/Desktop/Codex/research-briefings/2026-05-03/cross-cutting-and-filip-positioning.md
- Filip = founder OneFlow + ředitel CIAD
- Cíl: Q4 2026 = 50K LinkedIn / 100K X / 3 keynotes delivered

Deliverables (vše do `~/Desktop/Codex/research-briefings/2026-05-03/personal-brand/`):

1. `positioning-statement.md` — 1 sentence + 3-paragraph extended pro každou platformu (LinkedIn, X, podcast bio, conference bio)
2. `linkedin-bio-update.md` — current vs proposed bio + 5 featured posts plán
3. `x-bio-update.md` — current vs proposed (English-first)
4. `keynote-applications.md` — top 10 conference shortlist Q3-Q4 2026 (AI Summit, Fintech, Policy Forum) s deadlines + application drafts pro top 3 (čili 3 explicit pitch emails ready to send)
5. `content-pillar-plan-Q3-Q4.md` — week-by-week content schedule (LinkedIn 3×/week, X 5×/week, IG 2×/week, podcast 1×/2 weeks)
6. `podcast-target-list.md` — 20 podcasts (10 CZ + 10 EN) ranked by reach × fit × probability of acceptance, s 3 cold pitch emails ready

Voice: viz ~/.claude/rules/oneflow-all.md + filip-style-clone.md. CZ pro CZ audience, EN pro mezinárodní.

Anti-hallucination: konkrétní conference dates/deadlines verify přes WebSearch před zápisem. Žádné smyšlené konference.

Po dokončení: report do IMPLEMENTATION.md jako [x] + status report v 200 slov.
```

**Expected output:** 6 souborů v `personal-brand/` subdir
**Tools:** Write, WebSearch (conference validation), Read (rules + briefy)
**Skills:** brand-dna-extractor (pokud dostupný), prompt-master, copy-editing
**Verify before done:** Všech 6 souborů existuje, conference dates verified, žádné generické "thought leader" fráze.

---

## P2 — IMPLEMENTAČNÍ PROMPTY

### P2.1 — First CIAD Paper Draft

**Topic:** "Mechanistic Interpretability for Policy Makers: A Translation Guide"

**Copy-paste prompt:**
```
Draft first CIAD paper. Translates Anthropic mechanistic interpretability research do EU policy actionable language.

Kontext:
- Reference: ~/Desktop/Codex/research-briefings/2026-05-03/ciad-industry-deep.md (sekce hot research areas)
- Length: 25-40 stránek, format: arxiv-publishable
- Audience: EU AI Office, member-state regulators, policy think tanks (ne researchers)

Struktura:
1. Abstract (200 words)
2. Introduction — proč interpretability matters for policy (2-3 stránky)
3. Background — co dělá Anthropic, OpenAI, DeepMind v interpretability 2024-2026 (4-5 stránek, citation-heavy)
4. Klíčové techniky decoded — sparse autoencoders, dictionary learning, circuit analysis (5-7 stránek, accessible explanation)
5. Policy implications — high-risk AI systems, EU AI Act Article 14 (transparency), audit requirements (5-7 stránek)
6. Recommendations pro EU AI Office — 5 concrete actions (3-4 stránky)
7. Limitations + open questions (1-2 stránky)
8. References (min 30 citations, all verified)

Output:
- `~/Desktop/Codex/research-briefings/2026-05-03/CIAD-Paper-01-MechInterp-Policy.md` (full draft)
- `~/Desktop/Codex/research-briefings/2026-05-03/CIAD-Paper-01-citations.bib` (BibTeX)

Method:
- Spustí research subagent (research-paper skill nebo paper2code) na 30 nejcitovanějších interpretability papers 2023-2026
- Po research → draft sections 1-4 (Claude solo)
- Sekce 5-6 → Filip + Claude collaborative (potřeba CZ/EU policy nuance)
- /evalopt na final draft (rubric: scholarly, citations verified, no hallucinations, accessible)

Anti-hallucination HARDCORE: každá citace verified přes arxiv.org URL nebo Google Scholar. Žádné smyšlené paper titles, authors, conferences. Pokud nejde verify → vyhoď.

Stakes EXTRA HIGH: jednorázová ztráta credibility na CIAD první paper = irrecoverable.
```

**Expected output:** Paper draft + BibTeX, 25-40 stránek, ≥30 verified citations
**Tools:** WebFetch, WebSearch, research-paper skill, /evalopt
**Stakes:** Extra high → reasoning depth max, verify every citation
**Owner split:** Claude drafts sekce 1-4, Filip review + sekce 5-6

---

### P2.2 — Advisory Board Outreach

**Cíl:** 3 specific candidate names + outreach plan (warm intro path mapped) + draft cold email per candidate kdyby warm intro selhal.

**Copy-paste prompt:**
```
Map 3 advisory board candidates pro CIAD a draft outreach plan.

Kontext: ~/Desktop/Codex/research-briefings/2026-05-03/ciad-industry-deep.md sekce "Advisory board candidates"

Hledám 3 lidi z různých kategorií:
1. **Anthropic researcher** (mechanistic interpretability, alignment, or policy team) — kdo z Anthropicu má warm receptivity to non-US institutes? Chris Olah? Jared Kaplan? Sam McCandlish? Někdo z policy team?
2. **CZ academic AI lead** — z CIIRC ČVUT / FEL ČVUT / MFF UK / BUT Brno. Kdo má visibility, publication track record + politickou neutralitu?
3. **EU policy voice** — DG CONNECT alumni, Ada Lovelace contributor, GovAI fellow s EU mandátem.

Per candidate:
- Full name, current title, affiliation
- Why ideal fit pro CIAD specific
- Public profiles (LinkedIn, X, Google Scholar)
- Mutual connections (via Filip's network — check Apollo/LinkedIn)
- Warm intro path (kdo zná koho)
- Cold email draft (Voss calibrated CTA, žádné "dovoluji si")
- Proposed engagement (advisory frequency, compensation 0 nebo modest, term length)

Output:
- `~/Desktop/Codex/research-briefings/2026-05-03/CIAD-advisory-board-candidates.md`
- `~/Desktop/Codex/research-briefings/2026-05-03/CIAD-advisory-outreach-emails.md` (3 cold drafts ready)

Anti-hallucination: VERIFY candidate names + affiliations via Google Scholar, official institute pages, LinkedIn. NIKDY smyšlené researchers.

Skills: outreach-oneflow pro email drafts, /evalopt na drafts.

Po dokončení update IMPLEMENTATION.md + memory entry.
```

**Expected output:** 2 soubory s 3 verified candidates + 3 ready emails
**Tools:** WebSearch, WebFetch (Google Scholar, LinkedIn), Read
**Skills:** outreach-oneflow, /evalopt

---

### P2.3 — OneFlow Podcast Pilot

**Cíl:** 3 episode outlines + 1 fully-prepped recording brief (questions, hooks, talking points).

**Copy-paste prompt:**
```
Setup OneFlow podcast pilot — 3 episode outlines + 1 fully prepped recording.

Kontext:
- OneFlow podcast = mix Filip solo + guest interviews
- Audience: retail investoři + emitenti SMB + fundraising founders
- Format: 30-45 min, video + audio
- Reference: ~/Desktop/Codex/research-briefings/2026-05-03/oneflow-industry-deep.md sekce content + B2B outreach

3 epizody:
1. "ECSP a co to znamená pro CZ retail investora" (solo Filip, foundational episode)
2. Guest TBD — emitent CZ SMB, který shánël kapitál přes dluhopisy (case study format)
3. "AI v due diligence — jak OneFlow používá AI a kde NEDŮVĚŘUJE" (solo Filip, transparency angle, cross-pillar s CIAD)

Per episode:
- Hook (first 30 sec — emotional, specific, anti-clichéd)
- 5-7 main talking points
- Stories/examples (real, not generic)
- 3 contrarian takes (anti-consensus angle)
- CTA (calibrated Voss, žádné "subscribe!")
- Show notes draft (timestamps + links)

Plus 1 fully prepped recording brief pro epizodu #1 (Filip nahraje):
- Sentence-by-sentence skript pro hook
- Bullet outline pro main content
- 5 prep questions Filip si položí
- 3 audience response triggers (komentáře/Q&A material)

Output:
- `~/Desktop/Codex/research-briefings/2026-05-03/OneFlow-podcast-3-eps-outlines.md`
- `~/Desktop/Codex/research-briefings/2026-05-03/OneFlow-podcast-ep1-recording-brief.md`

Voice: ~/.claude/rules/oneflow-all.md + ~/.claude/rules/filip-autopilot.md.

Skills: ig-content-creator pre-step (hook craft), /evalopt po draftech.
```

---

## P3-P4 — REFERENCE (akce dispatched později, kontext připraven)

### P3.1 — "ECSP Masterclass" content series
- 5 IG carousels + LinkedIn long-posts
- Topic mapping (Q3 2026 calendar)
- Skill: ig-content-creator + content-repurpose
- Reference: oneflow-industry-deep.md sekce content gap analysis

### P3.2 — Green Bond pilot scoping
- Identify 1 CZ renewable energy emitent jako pilot (solar dev, wind, hydro)
- ESG narrative drafting + dluhopis structure
- Skill: dd-emitent + investment-memo

### P3.3 — Symposium 2027 venue + date lock
- CZ venue (Praha — Cubex / Forum Karlín / DOX), datum (květen-červen 2027)
- Format: 1 den, 100-150 ppl, 3 keynotes + 4 panels
- Reference: ciad-industry-deep.md sekce conferences

### P4.1 — EU Horizon Europe application
- Q1 2027 deadline, application Q3 2026 prep
- Topic: AI safety governance research, V4 perspective
- Reference: ciad-industry-deep.md sekce funding ecosystem

### P4.2 — Bank distribution partnership
- KB Spořitelna nebo ČSOB Pre warm intro path
- Pilot proposal: OneFlow ECSP-certified → bank channel access
- Reference: oneflow-industry-deep.md sekce competitive landscape

---

## DECISION POINTS PRO FILIPA (před začátkem každé P1)

Před spuštěním P1.1, P1.2, P1.3 zvaž:

1. **ECSP application timing** — jdeme Q2 (květen) nebo Q3 (srpen)? Q2 = first mover advantage ale risk nedoladěné aplikace. Q3 = bezpečnější ale ztrácíme 3 měsíce.
2. **CIAD Manifest single-author vs co-authored** — Filip solo (single voice, faster) NEBO Filip + advisor (více credibility, ale slower coordination). Default doporučení: Filip solo pro v1.0, co-authored pro 2nd paper.
3. **Personal brand "Post-Communist Founder" — confirm/pivot** — pokud rezonuje, lock; pokud ne, alternativy: "Founder ve V4 AI safety", "From Post-Communist to AI-First Finance" (variant), "European AI Governance Founder". Default: confirm zkusit 30 dní + měřit engagement.
4. **Bandwidth allocation** — hire ghostwriter Q2 ano/ne? CIAD papers vyžadují 40-60h/paper. Bez ghostwritera Filip má bandwidth jen na 1 paper/Q. Default doporučení: hire ghostwriter na CIAD content (200-400k Kč Q3-Q4 2026 budget).
5. **Cross-pillar revenue model** — kdy začít nabízet AI Act compliance audit retainery? Q3 2026 (riziko before-time) nebo Q1 2027 (riziko opportunity miss)? Default: zveřejnit nabídku Q4 2026 (po prvním paper publish).

---

## VERIFY BEFORE COMPLETION (každá akce P1-P4)

```
□ Konkrétní soubor existuje na očekávané cestě
□ Velikost souboru reasonable (ne empty, ne malformed)
□ Confidence markers v textu pro každý faktický claim
□ /evalopt run pokud high-stakes content (CIAD, klientské, investorské)
□ IMPLEMENTATION.md status updated z [ ] / [~] / [x] / [!]
□ Memory entry pro learnings (1-2 sentences proč to dopadlo tak)
□ Pokud blocked → "Hotovo X/Y, chybí Z protože W" reportovat Filipovi
```

---

## RECALL PATTERNS (pro Claude v nové session)

Pokud user zmíní:
- **"ECSP"** / **"compliance"** / **"OneFlow regulatory"** → P1.1 ECSP-GAP-ANALYSIS.md
- **"CIAD"** / **"institut"** / **"manifest"** / **"AI safety paper"** → P1.2 CIAD-MANIFEST + P2.1 First Paper
- **"personal brand"** / **"keynote"** / **"podcast"** / **"LinkedIn growth"** → P1.3 personal-brand/ subdir
- **"advisory board"** / **"Anthropic researcher"** → P2.2 CIAD-advisory-board-candidates.md
- **"podcast"** / **"OneFlow show"** → P2.3 OneFlow-podcast outlines
- **"strategy review"** / **"Q3 review"** / **"co dělat"** → INDEX.md sekce "Top-line"

Source files always-load při relevantní task:
- `~/Desktop/Codex/research-briefings/2026-05-03/INDEX.md`
- Plus appropriate deep brief (oneflow / ciad / cross-cutting)

---

## CRITICAL ANTI-PATTERNS (z research learnings)

1. **NIKDY neclaimovat ECSP timing bez verify** — exact enforcement date není 100% locked, varies per member-state implementation. Vždy [LIKELY 80%+] s WebSearch refresh.
2. **NIKDY neusing OpenAI Superalignment data jako benchmark** — post-Sutskever transition znamená current state UNCERTAIN. Reference Anthropic + DeepMind, ne OpenAI internal.
3. **NIKDY nepublikovat CIAD paper bez external peer review** — irrecoverable credibility loss možný. Min 1 academic + 1 policy reviewer před arxiv.
4. **NIKDY nesynonymovat "AI safety" a "AI ethics" v CIAD comms** — researchers reading and policy makers reading parse differently. Use specific term per audience.
5. **NIKDY necitovat smyšlené statistics** — research dospěl k mnoha [GUESS]/[UNCERTAIN] o velikosti CZ trhu, default rates, user counts. Vyhoď nebo flag explicitly v každém deliverable.
6. **NIKDY neslíbit "OneFlow ECSP-certified" před application processed** — CNB approval timeline 60-90 dní, marketing pre-approval = legal risk.

---

## END-OF-IMPLEMENTATION REVIEW (po dokončení P1-P4)

Spusti `/extract_learnings` skill na celý 90-day session log + update tento soubor s "Lessons Learned" sekcí.

Quarterly refresh tohoto souboru: srpen 2026 (T+90 days od dnes).

---

Dopita
