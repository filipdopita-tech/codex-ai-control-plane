"""Práce.cz search engine — Playwright fetch + infinite scroll + regex parser.

Práce.cz je Next.js SPA, listing limit ~40 cards per query (žádný load-more
přes URL pagination). Strategie: scroll-to-bottom přes Playwright, parse
JobCardHeader articles, regex extract title/company/location/url.

Card schema kompatibilní s jobs.cz scraper:
  jobad_id, title, url, company, location, salary, employment_type, posted,
  snippet, tags, source_page, source_portal.
"""
from __future__ import annotations

import html
import re
import time
from pathlib import Path
from typing import List, Optional, Union
from urllib.parse import quote, quote_plus

from playwright.sync_api import sync_playwright, TimeoutError as PWTimeout

UA = (
    "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 "
    "(KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36"
)
BASE = "https://www.prace.cz"
LISTING = BASE + "/nabidky/"
SOURCE_PORTAL = "prace.cz"


def build_url(query: Union[str, List[str]], location: Optional[str] = None) -> str:
    """Build prace.cz listing URL.

    Práce.cz nemá pagination přes URL — single fetch + scroll.
    """
    if isinstance(query, str):
        kws = [query] if query else []
    else:
        kws = list(query)
    parts = []
    for kw in kws:
        parts.append("q%5B%5D=" + quote(kw, safe=""))
    if location:
        parts.append("locality%5Bname%5D=" + quote(location, safe=""))
    return LISTING + ("?" + "&".join(parts) if parts else "")


def _scroll_to_load_all(page_obj, max_scrolls: int = 8, idle_after: int = 3, polite_delay: float = 1.2) -> int:
    """Scroll to bottom repeatedly until article count stabilizes.

    Returns final article count.
    """
    last = 0
    idle = 0
    for i in range(max_scrolls):
        page_obj.evaluate("window.scrollTo(0, document.body.scrollHeight)")
        time.sleep(polite_delay)
        cur = len(page_obj.query_selector_all("article"))
        if cur == last:
            idle += 1
            if idle >= idle_after:
                break
        else:
            idle = 0
        last = cur
    return last


def search(
    query: Union[str, List[str]],
    location: Optional[str] = None,
    max_pages: int = 1,
    polite_delay: float = 1.5,
    use_session: bool = False,
) -> List[dict]:
    """Scrape Práce.cz listing for given query/location.

    Note: Práce.cz nemá login session benefit (žádný auth content), use_session
    je accepted pro signature compatibility ale ignored.

    max_pages parameter je accepted ale Práce.cz vrací all results in 1 fetch
    (~40 cap), takže max_pages > 1 nemá efekt — kept for CLI parity.
    """
    url = build_url(query, location)
    print(f"  [prace.cz] fetching {url}")
    cards: List[dict] = []
    with sync_playwright() as p:
        browser = p.chromium.launch(
            headless=True, args=["--no-sandbox", "--disable-dev-shm-usage"]
        )
        ctx = browser.new_context(
            locale="cs-CZ",
            timezone_id="Europe/Prague",
            user_agent=UA,
            viewport={"width": 1366, "height": 900},
        )
        ctx.add_init_script(
            "Object.defineProperty(navigator,'webdriver',{get:()=>undefined});"
        )
        page = ctx.new_page()
        try:
            page.goto(url, wait_until="domcontentloaded", timeout=30000)
            try:
                page.wait_for_selector("article", timeout=12000)
            except PWTimeout:
                print("    [warn] no <article> seen in 12s — empty result?")
            time.sleep(polite_delay)
            total = _scroll_to_load_all(page)
            print(f"    {total} articles after scroll")
            html = page.content()
            cards = parse_listing_page(html, page_url=url)
        except PWTimeout as e:
            print(f"    [error] {e}")
        finally:
            browser.close()
    return cards


# Regex parser — Práce.cz HTML pattern (verified 2026-05-04, JobCardHeader-module)
_RE_ADVERT_LINK = re.compile(
    r"<a[^>]*data-testid=\"advert-link\"[^>]*href=\"(/nabidka/([a-f0-9-]+)/?[^\"]*)\"[^>]*>([^<]+)</a>",
    re.I,
)
_RE_LABEL_VALUE = re.compile(
    r"<span class=\"accessibility-hidden\">([^<:]+?)<!--\s*-->:</span><span[^>]*>([^<]+)",
    re.I,
)
_RE_NEW_TAG = re.compile(r"Nová nabídka", re.I)
_RE_SALARY = re.compile(r"(?<![\d.,])(?:\d{2,3}(?:[\s\u00a0]\d{3})+|\d{4,})\s*(?:Kč|EUR|€|USD|\$)(?:\s*/\s*\w+)?", re.I)


def parse_listing_page(html_text: str, page_url: str = "") -> List[dict]:
    """Parse Práce.cz listing HTML → list of card dicts.

    Card schema = jobs.cz parser parity, plus source_portal=prace.cz.
    """
    cards: List[dict] = []
    articles = re.findall(r"<article[^>]*>(.*?)</article>", html_text, re.DOTALL)
    for art in articles:
        if "data-testid=\"advert-link\"" not in art:
            continue  # signup/promo card, not a job
        d = {
            "jobad_id": "",
            "title": "",
            "url": "",
            "company": "",
            "location": "",
            "salary": "",
            "employment_type": "",
            "posted": "",
            "snippet": "",
            "tags": [],
            "source_page": page_url,
            "source_portal": SOURCE_PORTAL,
        }

        m = _RE_ADVERT_LINK.search(art)
        if m:
            href = m.group(1)
            uuid = m.group(2)
            title = re.sub(r"\s+", " ", m.group(3)).strip()
            d["jobad_id"] = f"prace.cz:{uuid}"
            d["url"] = href if href.startswith("http") else BASE + href
            d["title"] = html.unescape(title)

        # Lokalita / Název firmy / Typ úvazku via accessibility-hidden labels
        for label, value in _RE_LABEL_VALUE.findall(art):
            label_norm = label.strip().lower()
            value = html.unescape(re.sub(r"\s+", " ", value).strip())
            if label_norm.startswith("lokalita"):
                d["location"] = value
            elif label_norm.startswith("název firmy") or label_norm.startswith("nazev firmy"):
                d["company"] = value
            elif label_norm.startswith("typ úvazku") or label_norm.startswith("typ uvazku"):
                d["employment_type"] = value
            elif label_norm.startswith("mzda") or label_norm.startswith("plat"):
                d["salary"] = value

        # Salary fallback — regex on entire article text if not found in label
        if not d["salary"]:
            sm = _RE_SALARY.search(re.sub(r"<[^>]+>", " ", art))
            if sm:
                d["salary"] = sm.group(0).strip()

        # "Nová nabídka" → posted heuristic
        if _RE_NEW_TAG.search(art):
            d["posted"] = "Nová nabídka"

        # Skip cards without minimum data
        if not d["title"] or not d["url"]:
            continue
        cards.append(d)

    return cards


# CLI for ad-hoc test: python -m scraper.prace_cz "marketing manazer"
if __name__ == "__main__":
    import json
    import sys

    q = " ".join(sys.argv[1:]) if len(sys.argv) > 1 else "marketing manazer"
    out = search(q)
    print(f"\nTOTAL CARDS: {len(out)}")
    for c in out[:5]:
        print(json.dumps(c, ensure_ascii=False, indent=2))
