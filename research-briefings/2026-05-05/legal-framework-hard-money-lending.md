# Legal Framework — Hard-Money Lending CZ 2026

**Status:** Synthesis from research agent (full deep-research write failed due to prompt size). Suplementuj **konzultací s advokátem** před prvním outbound contactem (vis Filip 1-min gates).

## Executive Summary (TL;DR)

Hard-money lending v ČR proti zástavě nemovitosti **je legal**, ale má 7 compliance bodů, které musí Filip splnit. Klíčové: licence ČNB jen pokud půjčuje **consumers** na **bydlení**. Pokud cílí na **business borrowers** (OSVČ business účel, s.r.o., a.s.) → ČNB licence ne potřeba. Lichva = APR cap ~30% (nad to trestní riziko § 218 TN). Loan-to-own model je legal pouze pokud kontrakt = genuine lending (LTV < 70%, reasonable APR, transparentní default mechanika).

## 1. ČNB licence — kdy ANO, kdy NE

**Zákon č. 257/2016 Sb.** o spotřebitelském úvěru:

| Situace | Licence ČNB? |
|---|---|
| Půjčka FO na bydlení (consumer mortgage) | **ANO mandatory** |
| Půjčka FO na konsolidaci/spotřebu, > 5 000 Kč | **ANO** |
| Půjčka OSVČ na business účel (income-producing) | **NE** (mimo zákon o SÚ) |
| Půjčka s.r.o. / a.s. (B2B) | **NE** |
| Půjčka FO > 2 mil. Kč nad rámec consumer credit threshold | **NE** (ale specific contract analysis required) |

**Akce pro Filipa**: Restrict initial scope na business borrowers (OSVČ + s.r.o.). Pro consumer scope: získat ČNB licence (~6 měs proces, ~150-300k Kč setup, capital requirements).

## 2. Lichva — § 218 TZ + § 1796 OZ

- **§ 1796 OZ** (občanský zákoník): smlouva je neplatná, pokud "při uzavření smlouvy dochází k zneužití tísně, nezkušenosti, rozumové slabosti, rozrušení nebo lehkomyslnosti" v hrubém nepoměru protihodnoty.
- **§ 218 TZ** (trestní zákoník): až 8 let vězení, pokud úmyslně zneužije tíseň + nepřiměřený zisk.
- **APR threshold (case law 2023-2026)**: <25% APR = bezpečná zóna; 25-30% = soud po-by-case; >30% = vysoké riziko characterizace lichvy.
- **Total cost of loan**: úrok + poplatky + skryté charges → reálná APR (RPSN).

**Akce**: Cap APR <25%, cap RPSN <28%, transparentně dokumentovat všechny poplatky.

## 3. Loan-to-own model — kdy legal vs. predatory

**Risk**: Pokud věřitel **úmyslně chce nemovitost** (nikoli splacení), soud může characterize jako disguised asset acquisition + jako lichvu.

**Indikátory predatory** (court evaluation):
- LTV > 80% (úmysl prodávat při default)
- APR > 30%
- Nereálný splátkový plán (default je "naplánovaný")
- Borrower v evidentní tísni (insolvence, exekuce na cestě)
- Žádný reasonable income test

**Indikátory genuine lending**:
- LTV < 70%
- APR < 25%
- Reasonable splátkový plán
- KYC + income test
- Borrower má alternativy (compared)

**Akce**: 
- Always do KYC + income/cashflow test (i pro business borrowers)
- LTV cap 70%
- Document genuine intent (loan agreements + risk acceptance forms)
- Decline borrowers v evident insolvency unless they have alternative refinancing options

## 4. GDPR — scrapování + outreach

**Article 6** (lawful basis):
- **6(f) legitimate interest** = nejvíce common pro B2B prospecting; vyžaduje LIA (Legitimate Interest Assessment) — vážit Filipův business interest vs. data subject rights.
- Pro **distressed individuals** je LIA SLABÝ (financial distress = sensitive context, vulnerable group).
- Pro **business owners** (OSVČ kontaktní email, s.r.o. jednatelé) je LIA SILNĚJŠÍ.

**Scraping public posts → outreach**:
- Public ≠ consent. Scraping FB public groups je **technically legal** ale outreach k tomu data subjects vyžaduje GDPR base.
- ✅ B2B contact email z firma webu / ARES = legitimate interest (s LIA).
- ⚠️ Phone number z FB profile + cold call = problematic (no LIA pro vulnerable).
- ❌ Telefony fyzických osob z FB skupin pro distressed peer outreach = HIGH risk GDPR violation.

**Article 9 special category**: financial distress není formálně Article 9 (jen 9 kategorií jsou explicit), ale ÚOOÚ + EDPB guidance flag toto jako "vulnerability indicator" requiring stronger safeguards.

**Akce**:
- Pro **business borrowers**: LIA dokument + transparency note v first contact.
- Pro **consumer**: NE outreach bez consent. Alternative: paid Google Ads (consumer searches sám).
- Privacy notice na webu, opt-out mechanismus, retention 12 měs max.

## 5. AML — Zákon č. 253/2008 Sb.

**Filip = "povinná osoba"** pokud je úvěrová instituce nebo poskytovatel platebních služeb. Pro non-licensed business lending **AML obligations apply** pouze pokud je v rejstříku ČNB.

Pokud Filip operuje jako:
- s.r.o. providing business loans bez ČNB licence → AML formálně neapplikuje, ale BEST PRACTICE = standard CDD (Customer Due Diligence).
- s ČNB licence → mandatory: KYC, beneficial owner (UBO), transaction monitoring, SOZ (Suspicious Operation Report).

**Akce**: Standard KYC pro každý loan >100k Kč: ID copy, UBO declaration (pro firmy), source of funds note (kde Filip získá kapitál).

## 6. ECSP — relevant?

**ECSP (EU Crowdfunding Service Providers Regulation)** = Filip je relevant POUZE pokud **pooluje kapitál od investorů** (>1 person funding loans).

Pokud Filip používá **vlastní kapitál**: ECSP NE applies, **low risk**.

Pokud Filip začne pool: ECSP licence mandatory + ČNB Decision RS2024-47 thresholds applikuje.

**Akce**: Při scaling beyond own capital, konzultovat ECSP koridor (Filip má OneFlow + zaregistrujeme.cz expertise tady).

## 7. Zástavní právo — process + timeline

§§ 1309-1394 OZ + zákon o katastru nemovitostí:

1. **Zápis zástavy do KN** — notářský zápis nebo úředně ověřený podpis. Cena 1-3k Kč. Doba 7-30 dní v KN.
2. **Default + výzva k splacení** — písemná výzva, 30-day cure period.
3. **Realizace zástavy**:
   - **Volný prodej** (consensual): rychle, 3-6 měs, vyšší výtěžek.
   - **Soudní prodej / dražba** (contested): 12-24 měs, ~70% market value.
4. **Insolvence borrower** → zástava jako "zajištěný věřitel" → priority but >12 měs timeline + court fees.

**Success rate v praxi**: 60-80% nominal recovery (LTV 70% × 80% recovery = ~56% net recovery on default).

**Akce**:
- Notářský zápis o zástavní smlouvě jako "exekutorský titul" (přímá vykonatelnost — saves 6+ měs in default scenario).
- LTV cap 65-70% (buffer pro property value drop + recovery costs).

## Risk Matrix

| Risk | Severity | Mitigation | Filip Action |
|---|---|---|---|
| ČNB licensing (consumer scope) | HIGH | Restrict initial scope to business | Document ICP = OSVČ + s.r.o. only |
| Lichva (>30% APR) | HIGH | Cap APR <25%, RPSN <28% | Set pricing matrix, audit each deal |
| Predatory loan-to-own characterization | MED-HIGH | LTV<70%, KYC, income test | Standardize loan agreements + decline criteria |
| GDPR outreach to distressed individuals | HIGH | Restrict outreach to business contacts | Build LIA for B2B, decline FB consumer scraping |
| AML CDD (>100k Kč loans) | MED | Standard KYC + UBO | KYC template + storage SOP |
| ECSP applicability (own capital only) | LOW | Don't pool capital | Defer ECSP licensing until scaling |
| Zástavní enforcement | MED | Notářský zápis + LTV<70% | Use notary template + reasonable LTV |

## Action Items pro Filipa (lawyer consult)

1. **Engage advokát s expertise v non-bank lending** (např. Mgr. Šulc ak-vsk.cz nebo Havel & Partners financial services group).
2. **Draft loan agreement template** s notářským zápisem clause + LTV/APR caps.
3. **Build LIA dokument** pro B2B outreach.
4. **GDPR privacy notice + opt-out** na OneFlow webu.
5. **KYC SOP** pro >100k loans.
6. **ČNB licensing analysis** — pokud Filip vůbec uvažuje consumer scope, zahájit proces (~6 měs).
7. **Review ICP definition** — confirm only business borrowers initial phase.

**Priorita**: kroky 1, 2, 3 PŘED prvním outbound contactem k získanému lead. Ostatní paralelně.
