# ECSP Compliance Gap Analysis — OneFlow s.r.o.

**Datum:** 2026-05-03
**Author:** Claude Code (P1.1 z IMPLEMENTATION.md)
**Stakes:** HIGH — určuje legal pathway pro Q3-Q4 2026 revenue
**Confidence labeling:** `[VERIFIED]/[LIKELY 80%+]/[GUESS]/[UNCERTAIN]`

---

## REALITY CHECK — oprava timing assumption

Předchozí brief (`oneflow-industry-deep.md`, INDEX.md) tvrdil "ECSP květen 2026 = compliance window". **Tato premisa je FALEŠNÁ** [VERIFIED, multiple sources].

**Skutečnost:**
- Nařízení (EU) 2020/1503 (ECSP) **v platnosti od 10. 11. 2021** [VERIFIED — EUR-Lex]
- Transition period **skončil 10. 11. 2023** [VERIFIED — Reg 2022/1988]
- **Od 11/2023** musí mít každý poskytovatel investičního/úvěrového crowdfundingu pro projekty 1-5M EUR licenci od ČNB [VERIFIED — e15.cz, ČNB]
- ČR situace 2024-2026: **jen ~3 firmy získaly licenci**, ostatní operují v "šedé zóně" (penize.cz) [LIKELY — Q1 2026 stav]
- "Květen 2026" v původním briefu byl pravděpodobně **konflací s EU AI Act high-risk enforcement** (květen 2026 — separátní regulace, netýká se přímo crowdfundingu)

**Implikace pro OneFlow:** ECSP enforcement není budoucí window — **je TADY, 2.5 roku**. Otázka není "kdy se připravit", ale "v jakém režimu OneFlow aktuálně operuje a jaké riziko představuje legal exposure".

---

## STRATEGIC DECISION TREE — JAKÝ JE ONEFLOW MODEL?

ČNB stanovisko **RS2024-47** (10/2024) [VERIFIED — cnb.cz] určuje legal pathway pro online platformy umisťující dluhopisy. Pravidlo:

| Operating model | ECSP licence? | Alternativní compliance |
|---|---|---|
| **A. Vlastní emitenti** (OneFlow s.r.o. nebo její holding sám vydává dluhopisy) | NE — nepárují se zájmy | Prospekt dle ZPKT + ZDluh + AML + GDPR |
| **B. Propojení emitenti** (ovládací vztah s OneFlow přes vlastnictví / hlasovací práva / smlouvy) | **NELZE získat** — čl. 8 ECSP absolutní zákaz | Restruktura nutná, nebo jiný legal frame |
| **C. Nezávislí třetí emitenti** (žádný ovládací vztah) | **ANO — povinná** | + ECSP compliance (8 pilířů níže) |
| **D. Hybrid** (mix A+C) | Pro C část ANO | Strict separace, hold vlastní emise mimo platform |
| **E. Pouze "nabídka" bez RTO** (receiving + transmitting orders) | NE (možná výjimka) | MiFID light pro investment advice / placement |

**Otevřená otázka pro Filipa (P0 — bez odpovědi nelze pokračovat):**

> **Jaký je legal status 3 emisí (47M Kč) které OneFlow odbavila? Byly to:**
> - (a) vlastní emise OneFlow s.r.o. nebo jejího holdingu?
> - (b) emise emitentů propojených s OneFlow (Filip / společníci v cap table)?
> - (c) emise nezávislých třetích firem (OneFlow jako prostředník/marketing)?
> - (d) emise mimo crowdfunding rámec (pre-arranged investors, prospekt-lite, qualified-only)?

**Default working assumption (do potvrzení):** Scénář **D / E** — hybrid s důrazem na vlastní + qualified investor placement, mimo retail crowdfunding scope. To by vysvětlovalo absenci ČNB licence + reálný operating track record.

**Pokud se potvrdí scénář C** → ECSP licence je NEZBYTNÁ a OneFlow operuje aktuálně non-compliant. **HIGH risk, urgent legal triage**.

---

## 8 COMPLIANCE PILLARS — Gap Analysis Tabulka

Předpoklad: aplikuje se ECSP plně (scénář C nebo část D) — nejhorší case pro gap analysis. Pro scénář A platí jen pillars 1, 4, 7 (AML + GDPR + Marketing). Cost estimates v EUR.

| # | Pillar | ECSP článek | Current State OneFlow | Gap | Akce | Cost (EUR) |
|---|---|---|---|---|---|---|
| **1** | **AML/KYC** | čl. 4(1)(c), zákon č. 253/2008 (AML) | Pravděpodobně **manuální KYC** přes osobní onboarding [GUESS — žádný automated tooling visible v project files] | KYC automation, beneficial ownership audit (>25%), source-of-funds doc pro tickety >10k EUR, sankční list cross-check (OFAC/ESMA), transaction monitoring nad 50k CZK | **Implementace KYC SaaS** (Onfido / Veriff / Sumsub) + AML transaction monitoring + interní AML směrnice + ohlašovací povinnost na FAÚ MF | 8-15k initial + 3-6k/rok |
| **2** | **Prospekt / KIIS** | čl. 23 + Annex I, ZPKT § 34 | "3 emise, 47M Kč" — **prospekt format unknown** [UNCERTAIN] | KIIS (Key Investment Information Sheet) per project, financial ratios, default rate disclosure (čl. 20), risk factors v jasné řeči | Template KIIS dle Annex I (12 sekcí povinně), translation EN/CZ, financial advisor review per emise, public disclosure na platformě | 3-5k per emise (recurring) + 5k template setup |
| **3** | **Audit (>1M EUR)** | čl. 16(2)(a), ZoÚ | Žádný audit povinný pokud emise <1M EUR. Pro >1M EUR vyžaduje accountant audit. [LIKELY] | Big-4 nebo mid-tier audit pro každý project >1M EUR + roční audit OneFlow s.r.o. pokud platforma operuje s aktivy nad threshold | Tender 3 audit firem (BDO / Mazars / Grant Thornton), retainer 25-50k Kč/emise + 80-150k Kč/rok platform-level | 3-6k per emise + 8-15k/rok platform |
| **4** | **GDPR** | čl. 4(1)(c), GDPR direct + zákon 110/2019 | OneFlow s.r.o. má pravděpodobně **base GDPR** (privacy policy na webu) [LIKELY], ale **DPA/DPO/breach protocol unknown** | Privacy policy update per ECSP, investor consent explicit, retention 10Y, breach notification protocol <72h, DPO buď interní nebo external retainer | GDPR audit (právník 5-15h), breach plan dokumentace, register zpracování dat, případně external DPO retainer | 2-5k initial + 1-3k/rok |
| **5** | **Regulátorní reporting** | čl. 16, čl. 21, RTS 2022/2120 | Žádné formální reporting do ČNB [LIKELY — žádná licence = žádný reporting povinný v ECSP] | Quarterly ČNB reporting (transactions, defaults, complaints, capital), data formats per RTS 2022/2120, annual default rate calculation, investor base statistics | Reporting tooling (custom Postgres views nebo SaaS), compliance officer 0.2-0.5 FTE, ČNB submission pipeline | 2-4k initial + 8-15k/rok (FTE pro-rata) |
| **6** | **Cybersecurity / IT operational resilience** | čl. 12(2)(h), DORA cross-ref 2025 | OneFlow **infrastruktura na VPS Flash** [VERIFIED — memory], ale **ne formální ISO 27001/SOC2/penetration test** [GUESS] | Pen-test ročně, business continuity plan, encryption at rest/in transit, 2FA mandatory pro investor accounts, incident response, DORA-light compliance | Pen-test (ext. firma 3-8k EUR), BCM plan 2-5 stránek, /shannon AI pentester quarterly self-audit, hardening dle security-hardening rule | 5-10k initial + 4-8k/rok |
| **7** | **Investor protection / suitability** | čl. 21, čl. 22 | Žádný formální suitability/appropriateness test pro retail [LIKELY] | Pre-investment knowledge test (čl. 21), simulation of ability to bear loss (10% of net worth limit), 4-day reflection period mandatory pro non-sophisticated, risk warning v každém kroku | Onboarding wizard s 12-otázkovým knowledge testem, suitability score, automated warnings, reflection period UX, classification sophisticated vs non-sophisticated investor | 4-8k UX + dev (jednorázově) + 1-2k/rok refresh |
| **8** | **Marketing communications** | čl. 27 | OneFlow content na IG/LinkedIn/web [VERIFIED] — **bez formálního compliance review** | Každá investment komunikace: identifikovaná jako marketing, fair/clear/not misleading, balance risk/reward, žádné historické returns bez disclaimeru, žádné fake scarcity | Compliance review template per piece, ČNB marketing notification (RTS 2022/2123), interní reviewer (Filip nebo external retainer), banned-phrases list rozšířen o regulator triggers | 1-3k template setup + 2-5k/rok review retainer |
| **+** | **Vlastní kapitál (prudential)** | čl. 11 | s.r.o. minimum základní kapitál 1 Kč; OneFlow konkrétní zůstatek **UNCERTAIN** | **min(25,000 EUR; 25% fixních provozních nákladů)** musí být udržováno průběžně, plus pojištění odpovědnosti nebo equivalent guarantee | Kapitalizace s.r.o. na min. 650k Kč (~25k EUR), pojistka občanskoprávní odpovědnosti, čtvrtletní kapitálové výkazy | 25k EUR equity (lze ze zisku) + 1-2k/rok pojistka |

**Total cost estimate first year (scénář C, full ECSP):** **45-80k EUR** (1.1-2.0M Kč) — kapital + setup + compliance officer pro-rata + audit + IT + marketing.
**Recurring (year 2+):** **25-45k EUR/rok** (~600k-1.1M Kč/rok).

**Pokud scénář A (vlastní emise):** redukce ~60-70% (pillars 1, 4, 7, 8 + prospekt) → **15-25k EUR setup + 8-15k/rok**.

---

## 30-DAY ACTION PLAN

**Předpoklad:** Aktuální datum = 2026-05-03. Deadlines = T+N dní.

### Týden 1 (T+0–7) — Legal triage [P0 BLOCKER]

| Akce | Owner | Output | Stav |
|---|---|---|---|
| Konzultace s capital markets právníkem (Schejbal&Partners, KLB Legal, Finreg.cz) — 1.5h zdarma intro | Filip | Email 3 firmám, schedule 1 call do T+5 | Pending |
| Předat právníkovi: 3 emise dokumenty (smlouvy, prospekty/info materiály, cap table emitentů) + ČNB stanovisko RS2024-47 | Filip | Memo "OneFlow legal status" z právníka | Pending |
| Závěr: scénář A/B/C/D/E + risk exposure pokud non-compliant | Filip + právník | 2-stránkové stanovisko | Pending |

### Týden 2 (T+8–14) — Strategic decision

| Akce | Owner | Output | Stav |
|---|---|---|---|
| Pokud scénář C → rozhodnutí: ECSP licence apply (12+ měsíců, 15-25k EUR) **nebo** business model pivot (vlastní emise, qualified-only, MiFID light) | Filip | Decision memo + budget commit | Pending |
| Pokud scénář A → audit prospekt compliance pro 3 dosavadní emise (retroactive risk) | Filip + právník | Compliance report per emise | Pending |
| Pokud scénář B → restruktura cap table emitentů NEBO ECSP-incompatible model → MiFID/qualified-only switch | Filip + právník | Restructure plan | Pending |

### Týden 3 (T+15–21) — Compliance baseline (univerzálně)

| Akce | Owner | Output | Stav |
|---|---|---|---|
| AML směrnice draft (interní procedury KYC, transaction monitoring threshold 50k Kč, FAÚ ohlašovací povinnost) | Claude (draft) + Filip (sign-off) | `aml-smernice-v1.md` | Pending |
| GDPR refresh: privacy policy update na oneflow.cz, breach notification protocol, register zpracování dat | Filip + právník | Updated privacy policy live | Pending |
| Marketing compliance template: per-piece review checklist, banned phrases (rozšířený oneflow-all.md `Banned Words`), historical returns disclaimer | Claude | `marketing-compliance-checklist.md` | Pending |

### Týden 4 (T+22–30) — Tooling + budget allocation

| Akce | Owner | Output | Stav |
|---|---|---|---|
| KYC SaaS evaluation: Onfido vs Veriff vs Sumsub vs Stripe Identity (cost, EU/CZ support, API quality) | Claude (research) + Filip (decision) | Tool decision memo | Pending |
| Pen-test booking (Q3 2026 slot, ext. firma) — quotes 3 firms (TwoSigma, AEC, Citadelo) | Filip | Booked Q3 slot | Pending |
| Capital uplift plan pro OneFlow s.r.o. — kapitál na 650k Kč (25k EUR) přes notářský zápis nebo retained earnings reinvest | Filip + účetní | Updated základní kapitál v OR | Pending |
| Budget commit Q3-Q4 2026: ECSP setup line item (45-80k EUR pro full, 15-25k pro vlastní-only) | Filip | Committed in OneFlow Q3 plan | Pending |

### Po 30 dnech — Decision gate

| Outcome | Next step |
|---|---|
| **Scénář A potvrzen + dosavadní emise compliant** | Standard compliance roll-out, ECSP licence není potřeba; focus na ZPKT/ZDluh prospekt rigor |
| **Scénář C potvrzen** | ECSP licence application kickoff (12+ měsíců timeline) — start s pre-filing konzultací ČNB |
| **Scénář B potvrzen** | Restruktura nebo pivot na qualified-investor only / MiFID light |
| **Scénář D/E (hybrid)** | Strict separace + dual-track: ECSP track pro public + private placement track pro qualified |

---

## ANTI-HALLUCINATION FLAGS

Faktické claims v tomto dokumentu:

- ECSP nařízení 2020/1503, články 4-27 [VERIFIED — EUR-Lex + WebFetch]
- ČNB application fee 20,000 Kč [VERIFIED — cnb.cz]
- ČNB řízení 12+ měsíců [LIKELY — multiple law firm sources, ne oficiální ČNB SLA]
- "Jen 3 firmy s licencí v ČR" [LIKELY — penize.cz Q1 2026, nepotvrzeno z primárního zdroje ČNB JERRS — JERRS dotaz selhal na 403]
- ČNB stanovisko RS2024-47 obsah [VERIFIED — cnb.cz]
- OneFlow current state (jako "platforma propojující firmy + investory", "3 emise, 47M Kč") [VERIFIED — project files]
- OneFlow ARES IČO [UNCERTAIN — ARES dotaz na "OneFlow" nevrátil match; potřeba Filipova IČO konfirmace]
- Cost estimates EUR [GUESS — odhady na základě CZ právních sazeb 2025-2026, mohou být +/-30%]
- Operating model OneFlow (scénář A/B/C/D/E) [UNCERTAIN — kritická informace, vyžaduje Filipovu odpověď v Týdnu 1]

**Verification stále chybí (P0 pro Filipa):**
1. OneFlow s.r.o. IČO + výše základního kapitálu (ARES check)
2. Legal struktura 3 emisí — kdo byl emitent, prospekt format
3. Cap table emitentů — ovládací vztahy s OneFlow
4. Aktuální AML směrnice / GDPR documentation status
5. ČNB pre-filing konzultace — jestli proběhla nebo ne

---

## RISKS & MITIGATIONS

1. **Legal exposure pokud scénář C bez licence** — ČNB může uložit pokutu až 5% obratu nebo 1M Kč (zákon č. 6/1993), zákaz činnosti, reputational damage. **Mitigation:** Týden 1 právní triage = NON-NEGOTIABLE before any další emise.

2. **12+ měsíců timeline ECSP licence** — pokud OneFlow čeká s aplikací do Q3 2026, licence Q3 2027 → ztráta 12 měsíců revenue window. **Mitigation:** Pokud scénář C, paralelní track: aplikace SUBMIT Q2 2026 + dočasný operating model (qualified-only / private placement) do schválení.

3. **Cost shock 45-80k EUR Y1** — bez schválené alokace ohrozí cashflow. **Mitigation:** Filip alokuje compliance line item v Q3 plan = part of "regulatory operating cost", ne discretionary marketing.

4. **AML/FAÚ ohlašovací povinnost retroactive** — pokud OneFlow měla podezřelé transakce a neohlašovala, retroactive expozice. **Mitigation:** Týden 3 AML směrnice draft + retroaktivní review 3 dosavadních emisí pro suspicious patterns.

5. **Marketing communications historical returns claim** — "0 defaultů z 47M Kč" může být ČNB-flagnutý jako misleading bez disclaimer. **Mitigation:** Update banned-phrases v oneflow-all.md, marketing review checklist v Týdnu 3.

---

## NEXT STEPS

1. **Filip review** tohoto dokumentu (15-20 min) — confirm assumptions o operating model
2. **P0 Týden 1** — kontaktovat 1 capital markets právníka do T+3 dní (Schejbal, KLB Legal, nebo Finreg.cz)
3. **Update IMPLEMENTATION.md** — status P1.1 → `[~]` po Filipově review, → `[x]` po dokončení Týdne 1 legal triage
4. **Memory entry** — `project_ecsp_gap_analysis_2026_05_03.md` s decision tree + hold pro Týden 1 outcome

---

## SOURCES (verified URLs)

- [EU Reg 2020/1503 (ECSP) full text](https://eur-lex.europa.eu/eli/reg/2020/1503/oj/eng)
- [ČNB povolovací řízení ECSP](https://www.cnb.cz/cs/dohled-financni-trh/vykon-dohledu/povolovaci-a-schvalovaci-rizeni/povolovaci-a-schvalovaci-rizeni-poskytovatele-sluzeb-skupinoveho-financovani/)
- [ČNB stanovisko RS2024-47 — propojení emitenti](https://www.cnb.cz/cs/dohled-financni-trh/legislativni-zakladna/stanoviska-k-regulaci-financniho-trhu/RS2024-47/)
- [Schejbal&Partners — ECSP licence guide](https://akschejbal.cz/licence-investicni-crowdfunding)
- [KLB Legal — crowdfunding licence](https://klblegal.cz/kapitalovy-trh/licence-od-cnb/crowdfunding/)
- [E15 — crowdfunding licence od 11/2023](https://www.e15.cz/byznys/finance-a-bankovnictvi/investicni-crowdfunding-od-tohoto-mesice-uz-jen-s-licenci-od-cnb-ne-vsichni-ji-vsak-museji-mit-1411656)
- [Penize.cz — jen 3 firmy s licencí](https://www.penize.cz/investice/448456-licence-na-crowdfunding-ziskaly-jen-tri-firmy-dalsi-zustaly-v-sede-zone) (403 fetch — title verified, content not directly read)
- [ESMA crowdfunding hub](https://www.esma.europa.eu/esmas-activities/investors-and-issuers/investment-services-and-crowdfunding)

Dopita
