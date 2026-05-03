# Wedos WAPI quirk discovery + v3 fix — 2026-05-03 23:40 CEST

## Bug found
`dns-row-update` returns `code 1000 OK` but **silently fails** when:
- `rdata` changes substantially (e.g. p=quarantine → p=reject + new flags)
- `ttl` parameter doesn't match existing DB row TTL
- Multiple `_dmarc` rows exist (only first updated)

API success ≠ DB write success. Wedos has internal validation that filters changes silently.

## Fix pattern (v3)
For each Wedos domain needing DMARC reject:
1. `dns-rows-list domain=X` → parse JSON, extract numeric `ID` for `name=_dmarc rdtype=TXT`
2. `dns-row-delete row_id=ID` for ALL existing `_dmarc` rows (handles duplicates)
3. `dns-row-add` with `ttl=300` (Wedos minimum), `name=_dmarc`, `type=TXT`, `rdata="v=DMARC1; p=reject; rua=...; pct=100; adkim=s; aspf=s"`
4. `dns-domain-commit name=X`
5. Wait 60s for NS reload, verify on auth NS

## Production state
- Primary script: `/root/scripts/automation/wedos-auto-finisher.sh` (v3 logic)
- Backup: `/root/scripts/automation/wedos-auto-finisher.sh.v1.bak`
- Cron: `17 * * * *` (idempotent, self-removes when done)

## Verified results (23:40 auth NS query)
5/6 sister domains = `p=reject` confirmed:
- oneflow-team.cz, oneflowteam.cz, helponeflow.cz, joinoneflow.cz, oneflowcast.cz

1/6 awaiting NS reload:
- help-oneflow.cz (DB has reject row 75258, Wedos NS still cached quarantine — propagates ≤15 min)

## Out-of-scope discovery
6 domains from original handoff list NOT in Wedos DNS:
- 5/6 unregistered (oneflow.investments, oneflow.fund, oneflowinvestments.com, oneflow-investments.com, fundup.cz)
- 1/6 Sedo parking (fundup.eu on sl1.sedo.com / sl2.sedo.com)

## ntfy IDs
- `s4gElpy3P5ft` — initial 1-min gate request
- `6yo4EZTxm7l5` — 5/6 sister DMARC live success
