"""StartupJobs.cz adapter — public JSON API (no auth).

Endpoint: https://www.startupjobs.cz/api/offers?paginator[page]=N
Returns 20 offers per page, ~479 total (24 pages).
Schema includes: id, name, url, company, locations, salary, seniorities,
areaNames, isRemote, isHot, isTop, isStartup.

Card schema parity with jobs.cz / prace.cz:
  jobad_id        startupjobs:{id}
  source_portal   startupjobs
"""
from __future__ import annotations

import html
import json
import re
import time
import urllib.parse
import urllib.request
import urllib.error
from typing import List, Optional, Union

UA = "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36"
API_BASE = "https://www.startupjobs.cz/api/offers"
SITE_BASE = "https://www.startupjobs.cz"
SOURCE_PORTAL = "startupjobs"


def _query_match(text: str, query: Union[str, List[str]]) -> bool:
    if not query:
        return True
    if isinstance(query, str):
        kws = [query]
    else:
        kws = list(query)
    text_l = text.lower()
    words = [w.strip().lower() for kw in kws for w in kw.split() if w.strip()]; return any(w in text_l for w in words) if words else True


def _fetch_page(page: int, timeout: int = 12) -> Optional[dict]:
    url = f"{API_BASE}?paginator%5Bpage%5D={page}"
    try:
        req = urllib.request.Request(url, headers={
            "User-Agent": UA,
            "Accept": "application/json,*/*",
            "Accept-Language": "cs-CZ,cs;q=0.9,en;q=0.5",
        })
        with urllib.request.urlopen(req, timeout=timeout) as r:
            body = r.read().decode("utf-8", errors="replace")
        return json.loads(body)
    except (urllib.error.URLError, urllib.error.HTTPError, TimeoutError, json.JSONDecodeError) as e:
        print(f"  [startupjobs] page {page} failed: {e}")
        return None


def _normalize_offer(o: dict) -> dict:
    """Convert StartupJobs offer JSON → unified card schema."""
    rel_url = o.get("url", "")
    if rel_url and not rel_url.startswith("http"):
        full_url = SITE_BASE + rel_url
    else:
        full_url = rel_url

    company = ""
    co = o.get("company")
    if isinstance(co, dict):
        company = co.get("name") or ""
    elif isinstance(co, str):
        company = co
    company = html.unescape(company.strip())

    locations_raw = o.get("locations") or ""
    if isinstance(locations_raw, list):
        location = ", ".join(str(x) for x in locations_raw if x)
    else:
        location = str(locations_raw or "")

    salary = ""
    sal = o.get("salary")
    if isinstance(sal, dict):
        amt_min = sal.get("amount_from") or sal.get("min") or ""
        amt_max = sal.get("amount_to") or sal.get("max") or ""
        cur = sal.get("currency") or "Kč"
        per = sal.get("period") or ""
        if amt_min and amt_max:
            salary = f"{amt_min} - {amt_max} {cur}{(' / ' + per) if per else ''}"
        elif amt_min:
            salary = f"od {amt_min} {cur}{(' / ' + per) if per else ''}"
    elif isinstance(sal, str):
        salary = sal

    seniorities = o.get("seniorities") or []
    if isinstance(seniorities, list):
        seniority_str = ", ".join(str(x) for x in seniorities)
    else:
        seniority_str = str(seniorities or "")

    desc_html = o.get("description", "")
    snippet = re.sub(r"<[^>]+>", " ", desc_html)
    snippet = re.sub(r"\s+", " ", html.unescape(snippet)).strip()[:400]

    tags = []
    if o.get("isRemote"):
        tags.append("remote")
    if o.get("isHot"):
        tags.append("hot")
    if o.get("isTop"):
        tags.append("top")
    if o.get("isStartup"):
        tags.append("startup")

    return {
        "jobad_id": f"startupjobs:{o.get('id')}",
        "title": html.unescape(o.get("name", "").strip()),
        "url": full_url,
        "company": company,
        "location": location,
        "salary": salary,
        "employment_type": seniority_str,
        "posted": "",  # API neposkytuje datum
        "snippet": snippet,
        "tags": tags,
        "source_page": API_BASE,
        "source_portal": SOURCE_PORTAL,
    }


def search(
    query: Union[str, List[str]] = "",
    location: Optional[str] = None,
    max_pages: int = 24,
    polite_delay: float = 0.5,
    use_session: bool = False,
) -> List[dict]:
    """Walk paginated /api/offers, normalize, optionally filter by query+location."""
    cards: List[dict] = []
    seen_ids = set()

    first = _fetch_page(1)
    if first is None:
        return cards
    pag = first.get("paginator", {})
    total_pages = min(int(pag.get("max", 1)), max_pages)
    print(f"  [startupjobs] {first.get('resultCount', '?')} offers across {total_pages} pages")

    pages_to_fetch = list(range(1, total_pages + 1))
    for p in pages_to_fetch:
        data = first if p == 1 else _fetch_page(p)
        if data is None:
            break
        for o in data.get("resultSet", []):
            if o.get("id") in seen_ids:
                continue
            seen_ids.add(o.get("id"))
            card = _normalize_offer(o)

            text_match = " ".join([card.get("title", ""), card.get("snippet", ""),
                                   card.get("company", ""), card.get("employment_type", "")])
            if query and not _query_match(text_match, query):
                continue
            if location and location.lower() not in (card.get("location", "") + " " + text_match).lower():
                continue
            cards.append(card)
        if p < total_pages and polite_delay:
            time.sleep(polite_delay)

    return cards


if __name__ == "__main__":
    import sys
    q = " ".join(sys.argv[1:]) if len(sys.argv) > 1 else ""
    out = search(query=q, max_pages=3)
    print(f"\nTOTAL FILTERED: {len(out)}")
    for c in out[:5]:
        print(json.dumps(c, ensure_ascii=False, indent=2))
