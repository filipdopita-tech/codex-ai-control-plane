"""jobs.cz search engine — paginated scrape přes Playwright + persistent session."""
from __future__ import annotations

import time
from pathlib import Path
from typing import List, Optional, Union

from playwright.sync_api import sync_playwright, TimeoutError as PWTimeout

SESSION = "/root/.credentials/jobs_cz_session.json"
UA = (
    "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 "
    "(KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36"
)
BASE = "https://www.jobs.cz/prace/"


def build_url(query: Union[str, List[str]], page: int = 1, location: Optional[str] = None) -> str:
    """Build jobs.cz search URL.
    query může být string nebo list (každý dostane vlastní q[]=)."""
    if isinstance(query, str):
        kws = [query]
    else:
        kws = list(query)
    parts = []
    for kw in kws:
        # naivní URL-encode pro Czech keywords (Playwright provide better, ale pro URL hex stačí)
        from urllib.parse import quote
        parts.append(f"q%5B%5D={quote(kw, safe='')}")
    if location:
        from urllib.parse import quote
        parts.append(f"locality%5Bname%5D={quote(location, safe='')}")
    if page > 1:
        parts.append(f"page={page}")
    return BASE + "?" + "&".join(parts)


def _fetch_html(page_obj, url: str, retries: int = 2) -> str:
    """Navigate + return HTML, with retry on transient failures."""
    last = None
    for attempt in range(retries + 1):
        try:
            page_obj.goto(url, wait_until="domcontentloaded", timeout=25000)
            time.sleep(2)
            return page_obj.content()
        except PWTimeout as e:
            last = e
            print(f"    [retry {attempt + 1}/{retries}] timeout — sleeping 3s")
            time.sleep(3)
    raise last  # type: ignore[misc]


def search(
    query: Union[str, List[str]],
    location: Optional[str] = None,
    max_pages: int = 10,
    use_session: bool = True,
    polite_delay: float = 1.5,
) -> List[dict]:
    """Scrape paginated search results. Returns list of card dicts."""
    from .parser import parse_listing_page

    results: List[dict] = []
    with sync_playwright() as p:
        browser = p.chromium.launch(headless=True, args=["--no-sandbox", "--disable-dev-shm-usage"])
        ctx_kwargs = dict(
            locale="cs-CZ",
            timezone_id="Europe/Prague",
            user_agent=UA,
            viewport={"width": 1366, "height": 900},
        )
        if use_session and Path(SESSION).exists():
            ctx_kwargs["storage_state"] = SESSION
        ctx = browser.new_context(**ctx_kwargs)
        ctx.add_init_script(
            "Object.defineProperty(navigator,'webdriver',{get:()=>undefined});"
        )
        page = ctx.new_page()

        seen_ids = set()
        for n in range(1, max_pages + 1):
            url = build_url(query, page=n, location=location)
            print(f"  [page {n}/{max_pages}] {url}")
            try:
                html = _fetch_html(page, url)
            except Exception as e:
                print(f"  [page {n}] fetch failed: {e} — stop pagination")
                break
            cards = parse_listing_page(html, page_url=url)
            if not cards:
                print(f"  [page {n}] no cards — stop pagination")
                break
            new_cards = [c for c in cards if c.get("jobad_id") and c["jobad_id"] not in seen_ids]
            for c in new_cards:
                seen_ids.add(c["jobad_id"])
            results.extend(new_cards)
            print(f"  [page {n}] +{len(new_cards)} new (total {len(results)})")
            if len(new_cards) == 0 and len(cards) > 0:
                print(f"  [page {n}] pagination loop — stop")
                break
            time.sleep(polite_delay)

        browser.close()
    return results
