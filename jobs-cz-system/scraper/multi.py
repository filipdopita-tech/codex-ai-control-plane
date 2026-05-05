"""Multi-portal search dispatcher.

Routes a single (query, location, pages, portals) request to per-portal
scrapers and merges results. Each card gets `source_portal` (for downstream
pivot + audit). De-duplication happens at the unified card level.

Currently supported portals:
  - jobs.cz   (primary, paginated, login session)
  - prace.cz  (Phase 2, single-page Playwright fetch + scroll)
"""
from __future__ import annotations

from typing import List, Optional, Sequence, Union

PORTAL_JOBSCZ = "jobs.cz"
PORTAL_PRACECZ = "prace.cz"
PORTAL_STARTUPJOBS = "startupjobs"
ALL_PORTALS = [PORTAL_JOBSCZ, PORTAL_PRACECZ, PORTAL_STARTUPJOBS]


def _normalize_portals(portals: Optional[Union[str, Sequence[str]]]) -> List[str]:
    if portals is None:
        return [PORTAL_JOBSCZ]
    if isinstance(portals, str):
        if portals == "all":
            return list(ALL_PORTALS)
        return [portals]
    out: List[str] = []
    for p in portals:
        if p == "all":
            out.extend(ALL_PORTALS)
        else:
            out.append(p)
    seen = set()
    uniq = []
    for p in out:
        if p not in seen:
            seen.add(p)
            uniq.append(p)
    return uniq


def search_multi(
    query: Union[str, List[str]],
    location: Optional[str] = None,
    max_pages: int = 5,
    portals: Optional[Union[str, Sequence[str]]] = None,
    use_session: bool = True,
) -> List[dict]:
    """Run the same query across given portals; tag each card with source_portal."""
    sel = _normalize_portals(portals)
    all_cards: List[dict] = []
    for p in sel:
        try:
            if p == PORTAL_JOBSCZ:
                from .search import search as _jobscz_search
                cards = _jobscz_search(
                    query, location=location, max_pages=max_pages, use_session=use_session
                )
                for c in cards:
                    c.setdefault("source_portal", PORTAL_JOBSCZ)
            elif p == PORTAL_PRACECZ:
                from .prace_cz import search as _pracecz_search
                cards = _pracecz_search(
                    query, location=location, max_pages=max_pages, use_session=False
                )
                for c in cards:
                    c.setdefault("source_portal", PORTAL_PRACECZ)
            elif p == PORTAL_STARTUPJOBS:
                from .startupjobs import search as _sj_search
                cards = _sj_search(
                    query, location=location, max_pages=max_pages, use_session=False
                )
                for c in cards:
                    c.setdefault("source_portal", PORTAL_STARTUPJOBS)
            else:
                print(f"  [multi] unknown portal {p!r}, skipping")
                continue
            print(f"  [multi] {p} -> {len(cards)} cards")
            all_cards.extend(cards)
        except Exception as e:
            print(f"  [multi] {p} FAILED: {e}")
    return all_cards
