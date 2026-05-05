# CIAD — Šulc memo implementation plan
**Created:** 2026-05-05 (Filip handoff prep pre-setkání 5.5.2026)
**Source:** Šulcův legal memo z 4.5.2026 (`Právní aspekty založení CIAD.docx`)
**Memory:** `~/.claude/projects/-Users-filipdopita-Desktop-Codex/memory/project_ciad_sulc_response_2026_05_04.md`

---

## TL;DR

Šulc validoval Filipovu Phase I research a navrhuje **konkrétní právní strukturu** pro CIAD:

1. **Forma:** Ústav dle § 402 OZ
2. **Název:** Český institut pro AI a data z. ú. (CIAD)
3. **Architektura:** Dual-entity (CIAD non-profit garant + komerční subjekt OneFlow)
4. **Governance:** Dopita + Šulc + 3rd člen SR + ředitel Chudoba
5. **Cost:** 45-60 tis založení / 85 tis one-time provoz / 5 tis/měs / + smlouvy/sponzoři/trademark = ~500-995 tis Kč Phase I+II
6. **Timeline:** 2-3 týdny založení
7. **Setkání 5.5.:** finalize 7 open questions + comp negotiation

---

## Co Šulc rozhodl (= NEnegotiateme, akceptujeme)

| # | Rozhodnutí | Rationale |
|---|---|---|
| 1 | **Ústav dle § 402 OZ** — ne spolek/nadace/s.r.o. | Match Filipova Phase I research; tax-friendly; flexibility advokacie + komerce |
| 2 | **Název Český institut pro AI a data z. ú.** | Standardní formát z. ú. = zapsaný ústav |
| 3 | **Sídlo Praha 1** | Default; Filip může push na konkrétní adresu |
| 4 | **Notář-procedurální flow** (osobně NEBO plná moc + ověřený podpis + čestná prohlášení + výpis RT) | Standard CZ právní procedura |
| 5 | **Dual-entity model:** CIAD garant + komerční subjekt | Avoids "skryté podnikání" risk pro non-profit |
| 6 | **Ústav poskytuje za stejných podmínek všem** | Non-discrimination per non-profit pravidel |
| 7 | **Trademark CZ + EUIPO** | Standard IP protection, cost ~30 tis za ~3 třídy |

---

## Co Filip MUSÍ rozhodnout PŘED setkáním (= 7 open questions)

### Q1: Zakladatelé — FO nebo PO?

| Option | Pro | Proti |
|---|---|---|
| **Filip osobně (FO)** | Osobní commitment + flexibility + governance simpler | Filipovo jméno trvale v rejstříku; pokud opustí roli, governance change |
| **OneFlow s.r.o. (PO)** | Distance Filipa od osobní reputace; OneFlow má reputation | Conflict of interest s komerčním subjektem; CIAD vypadá jako "OneFlow's institute" |
| **Hybrid: 2 FO (Filip + Šulc)** | Diverse founder set; signals partnership | Šulc už je v SR — duplicate role |
| **3 FO (Filip + Šulc + Chudoba)** | Match SR composition; clean structure | Chudoba TBD identity (Filip TODO confirm) |

**Recommend:** Hybrid 2-3 FO (Filip + Chudoba + možná Šulc). Šulc PO = OneFlow s.r.o. zakladatelem = conflict s dual-entity (komerční subjekt by neměl founderovat non-profit).

### Q2: Třetí člen správní rady (??? v Šulcově návrhu)

**Kandidáti per cross-cutting-and-filip-positioning.md:**
- Šárka Strachoňová — CIO, Czech AI Network (CZ AI ecosystem rep)
- AI/policy academic (CVUT, MFF UK, VŠE) — adds research credibility
- Anthropic CZ contact (signals international alignment)
- Petr Chvojka — TAČR / Horizon Europe expert (grant-fundraising network)
- Existing Filip mentor / advisor (z OneFlow advisory board)

**Recommend:** academic z CVUT FEL nebo MFF UK (AI ethics researcher) → optimal pro institut credibility + research output.

### Q3: Poradní orgán — rovnou ve statutu?

**Option A: Rovnou (Statute v1)** — explicit governance struktura, signal stability
**Option B: Později (Statute v2)** — flexibility, lower setup overhead

**Recommend:** Option B (později) — statut snadno amendovat per § 405 OZ, rovnou nedělej co nepotřebuješ. Add poradní orgán až bude scope justify (např. 5+ research projektů paralelně).

### Q4: Sponzoři — máte zájemce?

**Pre-existing OneFlow network:**
- Anthropic (Filip má kontakty per memory) — long-shot, but signal "AI safety alignment"
- CZ AI startupy (potenciální sponsoring za marketing exposure)
- CZ foundations (Avast Foundation, Vodafone Foundation, ČEZ Foundation)
- Filip's investor network (sole investors + family offices co support AI safety)
- TAČR + MŠMT granty (ne sponsoring, ale grant pipeline)

**Action item:** Filip mapuje 5-10 jmenovaných targets před setkáním → představí Šulcovi jako "warm pipeline".

### Q5: Daňový poradce — zapojit pro otázku odpočtu darů

Šulc explicitly defers. **Action:**
- Filip identifikuje OneFlow účetní/daňového poradce (existing relationship?)
- Pokud žádný → Šulc doporučí (ak-vsk má daňový tým)
- Cíl: confirm že dary na CIAD jsou daňově odečitatelné per § 20 odst. 8 zákona o daních z příjmů (vzdělávací účely)

### Q6: Trademark — kolik tříd a které?

**Doporučené Niceské třídy:**
- **35** — Business management consulting, marketing, PR (advocacy + consulting)
- **41** — Education, training, certification (CORE — CIAD certifikace)
- **42** — Scientific research, software, design (R&D + analýza dat)

**Cost:** CZ ~5000 Kč base + příplatky za třídy; EUIPO 850 EUR per třída + první příplatky → **~30 tis Kč pro CZ + ~70 tis Kč pro EU za 3 třídy**.

**Recommend:** CZ first (rychlejší + lehnejší), EUIPO Q4 2026 po brand validation.

### Q7: Statut — finální účel

**Šulcův návrh (v memo):**
> vzdělávací, certifikační, výzkumné a poradenské činnosti v oblasti umělé inteligence; vydávání certifikátů způsobilosti pro AI školitele a mentory; advocacy a zastupování zájmů AI komunity; organizace konferencí a vzdělávacích akcí

**Filip TODO confirm:**
- ✅ Vzdělávací — CORE
- ✅ Certifikační — CORE (revenue model)
- ✅ Výzkumná — CORE (raison d'être)
- ✅ Poradenská — CORE (revenue model)
- ⚠️ **Advocacy** — TBD (politicky senzitivní, může komplikovat granty od EU; ALE = differentiator vs IPSAS/Jagiello)
- ⚠️ **Vydávání certifikátů "AI školitele a mentory"** — TBD scope (jen training-of-trainers nebo i pro běžné AI praktiky?)

**Recommend:** Advocacy ANO (per ciad-industry-deep.md § first-mover positioning); certifikáty EXPAND scope (ne jen školitele, ale i AI Practitioner / AI Auditor / AI Risk Officer per EU AI Act enforcement potřeby).

---

## Comp structure proposal v3 (post-memo, pre-meeting)

**Trigger:** Šulc se sám navrhl do správní rady (NE jen advokát-na-hodiny). Comp musí reflect dual-role:

### Box 1: Board member role (governance)
- **Board fee:** 0-5 tis Kč/měs symbolický (per non-profit pravidel "skryté podnikání" risk)
- **Decision rights:** standard SR voting per stanovy
- **Reciprocal:** Šulc získá CV/reputation entry "Member, Správní rada CIAD"

### Box 2: Legal services retainer (operational)
- **Base retainer:** 5 tis Kč/měs (match Šulcovo provoz fee v memo)
- **Hourly rate:** 1500-2500 Kč/hod pro Phase I+II milestone work (capped, milestone-based)
- **Scope:** zakladatelské dokumenty, statut, smlouvy, GDPR, governance, trademark

### Box 3: Klient pipeline OneFlow → ak-vsk (reciprocal value, NON-CASH)
- Každý OneFlow ECSP/dluhopisový/tech-startup klient s legal need = warm intro Šulcovi
- **Tracking:** quarterly review, # warm intros + # signed contracts
- **No commission** (peer relationship, ne sales channel)

### Box 4: Success fee na získané grants pro CIAD
- **Rate:** 3-5% z grant amount, capped per project
- **Scope:** Horizon Europe, TAČR, MŠMT (CIAD as recipient)
- **Aligned:** Šulc has skin in the game na grant pipeline

### Box 5: Trademark + IP services
- Discounted base rate (jako board member)
- One-time pro CZ + EUIPO submissions
- Recurring pro IP monitoring + enforcement

### NO list (out of question — nenegociovatelné)
- ❌ Equity v CIAD non-profit (illegal/governance konflikt)
- ❌ Revenue share na CIAD příjmech (compromises non-profit status)
- ❌ Revenue share na OneFlow s.r.o. (separate business unit, conflict)
- ❌ Profit-sharing na komerčním subjektu (potenciální skryté podnikání signal)

### Total annual estimate (rok 1)

| Box | Min | Max |
|---|---|---|
| Box 1 board fee | 0 | 60 tis |
| Box 2 retainer + hourly Phase I+II | 260 | 460 tis |
| Box 3 klient pipeline (cash) | 0 | 0 |
| Box 4 success fee | 0 | 50 tis |
| Box 5 trademark + IP | 30 | 70 tis |
| **TOTAL** | **290 tis** | **640 tis Kč** |

**Aligned s Šulcovým "půl milionu plus" floorem.** Filip má room negotiate down 290-450 tis za year-1 baseline (less aggressive scope), nebo confirm 500-640 tis (full Phase I+II accelerated).

---

## Setkání 5.5.2026 — agenda (60-90 min)

### Část 1 — Validation (15 min)
- Filip potvrzuje pochopení dual-entity architecture
- Validate Chudoba (kdo + relationship + commitment)
- Confirm Q3, Q6, Q7 rozhodnutí

### Část 2 — Governance + Sponzoři (15 min)
- Q1: zakladatelé final
- Q2: 3rd SR member (Filip má kandidáta?)
- Q4: sponsorský pipeline mapping (5-10 targets)
- Q5: daňový poradce assignment

### Část 3 — Comp negotiation (20 min) — CRITICAL
- Filip prezentuje 5-box framework
- Negotiate konkrétní hodinová sazba + retainer
- Confirm reciprocal klient pipeline mechanics
- Confirm success fee % na granty

### Část 4 — Timeline + Next steps (15 min)
- Notář scheduling (Šulc doporučí?)
- Trademark CZ submission Q3 2026
- Statut draft 1 týden post-meeting
- Next call after notarization (~3-4 týdny)

### Část 5 — Brand + Landing (5 min)
- Confirm "Český institut pro AI a data z. ú." finalní (žádné trademark konflikty)
- Landing page launch plan (post-notář ~3-4 týdny)
- Brand work paralelně OK

---

## Implementation roadmap (post-meeting)

### Týden 1 (5.-12. května 2026)
- [ ] Šulc draft engagement letter (comp v3 framework)
- [ ] Filip identifikuje Chudoba + 3rd SR member
- [ ] Filip mapuje sponzorský pipeline (5-10 targets)
- [ ] Filip + daňový poradce kick-off call

### Týden 2-3 (13.-26. května 2026)
- [ ] Statut draft v1 (Šulc)
- [ ] Zakladatelské dokumenty draft (Šulc)
- [ ] Filip + zakladatelé review + iterate

### Týden 4-5 (27. května - 9. června 2026)
- [ ] Notář scheduling + signing
- [ ] Zápis do rejstříku ústavů (~ 2-4 týdny processing)
- [ ] Trademark CZ submission (paralelně)

### Týden 6-10 (10. června - 14. července 2026)
- [ ] CIAD officially registered ✓
- [ ] Bank account setup (CIAD z. ú.)
- [ ] Landing page go-live (Filip má design + copy ready per project_ciad_brand_brief_2026_04_29.md)
- [ ] Sponsorship outreach (warm intros via Filip + Šulc)

### Týden 11-26 (Q3 2026 — full launch)
- [ ] First sponsor signed
- [ ] First grant application submitted (Horizon Europe nebo TAČR)
- [ ] First certifikační program defined + launched
- [ ] First komerční subjekt smlouva (OneFlow ↔ CIAD) signed
- [ ] First training/poradenství delivered přes komerční subjekt

### Q4 2026 — operational
- [ ] EUIPO trademark submission
- [ ] Quarterly board review (Šulc retainer mechanics check)
- [ ] First public symposium / conference (per ciad-industry-deep.md § 6)
- [ ] Annual report + tax filings

---

## Cross-references

| Artefakt | Status | Action |
|---|---|---|
| Memory `project_ciad_sulc_response_2026_05_04.md` | ✅ Written | Update post-meeting |
| `ciad-industry-deep.md` § 6 | ✅ Updated s legal advisor section | Update post-meeting s final comp + governance |
| `project_ai_asociace_2026_advokat.md` | ✅ Updated 2026-05-04 section | Update post-meeting |
| `project_ciad_brand_brief_2026_04_29.md` | TBD review | Confirm "Český institut pro AI a data z. ú." finalní |
| `auto_ciad_cz_coming_soon_launch.md` | Archive — pending notář | Trigger po registration |
| Obsidian `03-Projects/AI-Asociace-2026/sulc-response-2026-05-04/` | ✅ Created | Add MOC link from project hub |
| `decisions.jsonl` | TODO | Append post-meeting (ústav § 402, dual-entity, comp v3) |
| Šulc engagement letter | TODO | Šulc drafts post-meeting |
| Statut draft v1 | TODO | Šulc drafts week 1-2 post-meeting |

---

## Files generated this session (5.5.2026)

```
~/Documents/ai-asociace-2026-ADVOKAT-EXPORT/sulc-response-2026-05-04/
├── sulc-pravni-aspekty-zalozeni-CIAD.docx     (17070 B — original příloha)
├── sulc-pravni-aspekty-zalozeni-CIAD.md       (4601 B — converted)
└── sulc-email-body-2026-05-04.txt              (4214 B — email body)

~/Documents/OneFlow-Vault/03-Projects/AI-Asociace-2026/sulc-response-2026-05-04/
└── (Obsidian note → see vault)

~/Desktop/Codex/research-briefings/2026-05-05/
└── CIAD-SULC-MEMO-IMPLEMENTATION-PLAN.md       (this file)

~/.claude/projects/-Users-filipdopita-Desktop-Codex/memory/
└── project_ciad_sulc_response_2026_05_04.md   (full memory entry)

~/Desktop/Codex/research-briefings/2026-05-03/
└── ciad-industry-deep.md                       (§ 6 updated s legal advisor)

~/.claude/projects/-Users-filipdopita/memory/
└── project_ai_asociace_2026_advokat.md         (UPDATE 2026-05-04 sekce)
```

**Konec implementation plánu.** Filip má všechno co potřebuje pro 60-90 min setkání + post-meeting roadmap.
