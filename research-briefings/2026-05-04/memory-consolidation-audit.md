# Memory Consolidation Audit — 2026-05-04

> Generated as part of "1000% full fáze" wave. Conservative — surfaces facts, NO mass move.

## Two memory locations (split state)

### Legacy (active write target from older sessions)
**Path**: `~/.claude/projects/-Users-filipdopita/memory/`

| Metric | Value |
|---|---|
| Total .md files | 779 |
| Size | 4.3 MB |
| Modified ≤7d | 472 |
| Stale >180d | 0 (all relatively recent) |
| `project_*` | 118 |
| `reference_*` | 57 |
| `feedback_*` | 44 |
| `user_*` | 2 |
| `auto_*` (auto-memory entries) | many — appended by previous sessions |
| Uncategorized | 558 |

### New canonical (current session writes here)
**Path**: `~/.claude/projects/-Users-filipdopita-Desktop-Codex/memory/`

| Metric | Value |
|---|---|
| Total .md files | 44 |
| Size | 388 KB |
| MEMORY.md (manifest) | Active |

## Why two paths?

- Legacy = older Claude Code session resolution (parent of all Filip projects)
- New canonical = scoped to Desktop/Codex working dir (per CLAUDE.md "auto memory" instruction)

CLAUDE.md instruction explicitly directs writes to `-Users-filipdopita-Desktop-Codex/memory/`. Older sessions before this instruction wrote to legacy.

## Auto-memory entries from earlier today (legacy path)

Recent (this morning, before current Claude session active):
- `auto_stop_email_sending_20260504.md` (Filip "zastav odesílání mailů")
- `auto_linkedin_oauth_refresh_setup.md` (LI Publisher OAuth refresh setup)
- `auto_linkedin_secret_instructions.md`
- `auto_verify_flag_reference.md`
- `auto_ecosystem_audit_full_2026_05_04.md`
- `auto_ares_enrichment_report.md`

These contain valuable context that overlaps with project_* files in same dir but were written by auto-memory automation hook.

## Recommendation (NO mass move per Filip rule)

### Option 1 — Soft merge (preferred)
1. Keep both paths active
2. New sessions write to canonical (per CLAUDE.md)
3. Cross-reference both via /findall (already does this)
4. Periodic targeted moves: when a topic transitions from "active" to "reference", move that file to canonical with proper categorization

### Option 2 — Symlink consolidation (medium risk)
1. Create symlink `~/.claude/projects/-Users-filipdopita-Desktop-Codex/memory-legacy/` → `~/.claude/projects/-Users-filipdopita/memory/`
2. /findall already covers both, no behavior change
3. Visual unification only

### Option 3 — Full migration (HIGH RISK, NOT recommended)
1. rsync legacy → canonical, deduplicate by filename
2. Update all internal cross-references
3. Risk: breaks `/findall`, breaks any auto-memory writer that hardcoded legacy path

## What I did NOT do this session

- ❌ Mass move legacy → canonical (per Filip rule)
- ❌ Auto-promote `auto_*` files to project/reference categorization
- ❌ Delete duplicate content

## What I DID do (this audit alone)

- ✅ Surfaced state (779 vs 44 file split)
- ✅ Identified auto-memory writes patterns
- ✅ Three-option recommendation matrix
- ✅ Filip review needed before any move

## Filip 1-min decisions needed

- [ ] Which option? (1, 2, 3, or "leave as-is")
- [ ] If Option 1: any files Filip wants moved manually?

## Files

- Legacy memory: `~/.claude/projects/-Users-filipdopita/memory/` (779 files)
- New canonical: `~/.claude/projects/-Users-filipdopita-Desktop-Codex/memory/` (44 files)

— Dopita
