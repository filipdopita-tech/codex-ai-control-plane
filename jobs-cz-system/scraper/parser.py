"""HTML parsers — listing cards (search results) + detail pages.

Selektory založeny na actual jobs.cz layout (verified 2026-05-04):
  - article.SearchResultCard            — card root
  - h2.SearchResultCard__title          — title h2 with data-test-ad-title attr
  - a.SearchResultCard__titleLink       — title link (href = detail URL)
  - a[data-jobad-id]                    — jobad ID
  - [data-test-ad-status]               — posted date / status badge
  - .SearchResultCard__footerItem       — footer items (company, location, salary, type)
  - li[data-test="serp-locality"]       — location item
  - span[translate="no"]                — usually company (translate-no marker)
  - .Tag                                — tag chips
"""
from __future__ import annotations

import re
from typing import List, Optional

from bs4 import BeautifulSoup, Tag


def _txt(el: Optional[Tag], limit: int = 0) -> str:
    if not el:
        return ""
    s = el.get_text(separator=" ", strip=True)
    s = re.sub(r"\s+", " ", s).strip()
    return s[:limit] if limit else s


# Salary heuristic — CZ patterns: "30 000 - 50 000 Kč", "50 000 Kč/měsíc"
_SALARY_RE = re.compile(r"\d[\d\s]{2,}\s*(?:Kč|EUR|€|USD|\$)|(?:Kč|EUR|\$)\s*\d", re.I)
# Employment type heuristic
_EMPL_KEYWORDS = re.compile(r"plný úvazek|částečný|hpp|dpp|dpč|brigád|práce z domova|home office|hybrid|remote|kontrakt|freelance", re.I)


def parse_listing_page(html: str, page_url: str = "") -> List[dict]:
    """Parse search result HTML → list of card dicts.

    Pokrytí: title, url, jobad_id, company, location, salary, posted, tags, employment_type."""
    soup = BeautifulSoup(html, "html.parser")
    cards: List[dict] = []
    arts = soup.select("article.SearchResultCard, article[class*='ResultCard']")
    if not arts:
        arts = soup.select("article")

    for art in arts:
        d: dict = {
            "jobad_id": "", "title": "", "url": "", "company": "", "location": "",
            "salary": "", "employment_type": "", "posted": "", "snippet": "",
            "tags": [], "source_page": page_url,
        }

        # Title link → jobad_id, title, url
        link = art.select_one("a.SearchResultCard__titleLink, a[data-jobad-id]")
        if link:
            d["jobad_id"] = link.get("data-jobad-id") or ""
            d["url"] = link.get("href") or ""
            if d["url"].startswith("/"):
                d["url"] = "https://www.jobs.cz" + d["url"]
            d["title"] = _txt(link)

        # h2 with data-test-ad-title attr (cleaner — no whitespace)
        h2 = art.select_one("h2[data-test-ad-title], [data-test-ad-title]")
        if h2:
            attr_title = h2.get("data-test-ad-title", "")
            if attr_title:
                d["title"] = attr_title.strip()

        # Posted / status
        status = art.select_one("[data-test-ad-status]")
        if status:
            d["posted"] = _txt(status, 80)

        # Footer items — iterate, classify by content / data-test attribute
        for li in art.select(".SearchResultCard__footerItem"):
            txt = _txt(li, 200)
            if not txt:
                continue
            # Location — explicit data-test
            if li.get("data-test") == "serp-locality" or "serp-locality" in (li.get("data-test", "")):
                d["location"] = txt
                continue
            # Company — usually has translate="no" span inside
            comp_span = li.select_one('span[translate="no"]')
            if comp_span and not d["company"]:
                d["company"] = _txt(comp_span, 200)
                continue
            # Salary heuristic
            if _SALARY_RE.search(txt) and not d["salary"]:
                d["salary"] = txt
                continue
            # Employment type heuristic
            if _EMPL_KEYWORDS.search(txt) and not d["employment_type"]:
                d["employment_type"] = txt
                continue

        # Fallback: company from any translate=no span anywhere in card
        if not d["company"]:
            comp = art.select_one('span[translate="no"]')
            if comp:
                d["company"] = _txt(comp, 200)

        # Tags
        tags = []
        seen = set()
        for t in art.select(".Tag, [class*='Tag--']"):
            txt = _txt(t)
            key = txt.lower()
            if 1 < len(txt) < 80 and key not in seen:
                seen.add(key)
                tags.append(txt)
        d["tags"] = tags[:15]

        # Snippet from body
        body = art.select_one(".SearchResultCard__body")
        if body:
            d["snippet"] = _txt(body, 400)

        if d["jobad_id"] or d["url"] or d["title"]:
            cards.append(d)

    return cards


def parse_detail_page(html: str, url: str = "") -> dict:
    """Parse single job detail page — extra fields beyond listing card.

    Užitečné pro: kontaktní údaje firmy, full description, requirements, benefits."""
    soup = BeautifulSoup(html, "html.parser")
    d: dict = {"url": url, "title": "", "company": "", "description": "", "requirements": "",
               "benefits": "", "contact_email": "", "contact_phone": "", "company_url": ""}

    title_el = soup.select_one("h1[data-test-ad-title], h1")
    d["title"] = _txt(title_el) if title_el else ""

    # Company link
    comp_el = soup.select_one('a[data-test-employer-link], [data-test-employer] a, span[translate="no"]')
    d["company"] = _txt(comp_el, 200) if comp_el else ""
    if comp_el and comp_el.has_attr("href"):
        href = comp_el["href"]
        if href.startswith("/"):
            href = "https://www.jobs.cz" + href
        d["company_url"] = href

    # Full description
    desc_el = soup.select_one("[class*='Description'], [class*='JobDescription'], main")
    d["description"] = _txt(desc_el, 5000) if desc_el else ""

    # Email + phone scrape from text
    text = soup.get_text(" ")
    emails = re.findall(r"[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}", text)
    if emails:
        # Filter out tracking / no-reply patterns
        good = [e for e in emails if not any(b in e.lower() for b in ("noreply", "no-reply", "donotreply", "tracking", "@jobs.cz"))]
        d["contact_email"] = good[0] if good else emails[0]
    phones = re.findall(r"(\+?\d{3}[\s\-]?\d{3}[\s\-]?\d{3}[\s\-]?\d{0,3})", text)
    if phones:
        d["contact_phone"] = phones[0].strip()

    return d
