"""HTML parsers — listing cards (search results) + detail pages.

Robust strategy: try multiple selectors per field, fall back to attribute scrape.
jobs.cz layout může mírně měnit — selectory jsou broad fuzzy match na class names."""
from __future__ import annotations

import re
from typing import List, Optional

from bs4 import BeautifulSoup, Tag


def _txt(el: Optional[Tag], limit: int = 0) -> str:
    if not el:
        return ""
    s = el.get_text(separator=" ", strip=True)
    s = re.sub(r"\s+", " ", s)
    return s[:limit] if limit else s


def _select_first(art: Tag, *selectors: str) -> Optional[Tag]:
    for sel in selectors:
        el = art.select_one(sel)
        if el:
            return el
    return None


def parse_listing_page(html: str, page_url: str = "") -> List[dict]:
    """Parse search result HTML → list of card dicts.

    Pokrytí: title, url, jobad_id, company, location, salary, posted, snippet, tags."""
    soup = BeautifulSoup(html, "html.parser")
    cards: List[dict] = []
    # Primary selector
    arts = soup.select("article[data-jobad-id]")
    if not arts:
        arts = soup.select("[data-jobad-id]")
    if not arts:
        arts = soup.select("article")

    for art in arts:
        d: dict = {"jobad_id": "", "title": "", "url": "", "company": "", "location": "",
                   "salary": "", "posted": "", "snippet": "", "tags": [], "source_page": page_url}
        d["jobad_id"] = art.get("data-jobad-id") or art.get("id") or ""

        # Title + URL
        title_el = _select_first(
            art,
            "h2 a", "h3 a",
            "[class*='Title'] a", "[class*='title'] a",
            "a[data-link-name]",
            "a[href*='/rpd/']",
            "a[href*='/job/']",
        )
        if title_el:
            d["title"] = _txt(title_el)
            href = title_el.get("href", "")
            if href:
                if href.startswith("/"):
                    href = "https://www.jobs.cz" + href
                d["url"] = href

        # Company
        comp_el = _select_first(
            art,
            "[class*='Company']", "[class*='company']",
            "[class*='Subject']", "[class*='subject']",
            "[class*='Employer']", "[class*='employer']",
            "[data-link-name='company']",
        )
        d["company"] = _txt(comp_el, 200)

        # Location
        loc_el = _select_first(
            art,
            "[class*='Location']", "[class*='location']",
            "[class*='Locality']", "[class*='locality']",
            "[data-link-name='locality']",
        )
        d["location"] = _txt(loc_el, 200)

        # Salary / wage
        sal_el = _select_first(
            art,
            "[class*='Salary']", "[class*='salary']",
            "[class*='Wage']", "[class*='wage']",
            "[class*='Mzd']", "[class*='mzd']",
            "[class*='Plat']", "[class*='plat']",
        )
        d["salary"] = _txt(sal_el, 100)

        # Posted date / freshness
        date_el = _select_first(art, "time", "[class*='Date']", "[class*='date']", "[class*='Posted']", "[class*='posted']")
        d["posted"] = _txt(date_el, 80)
        if date_el and date_el.has_attr("datetime"):
            d["posted_iso"] = date_el["datetime"]

        # Snippet / description preview
        snip_el = _select_first(art, "[class*='Description']", "[class*='description']", "[class*='Summary']", "[class*='summary']", "p")
        d["snippet"] = _txt(snip_el, 400)

        # Tags / chips / badges
        tag_els = art.select("[class*='Tag'], [class*='tag'], [class*='Chip'], [class*='chip'], [class*='Badge'], [class*='badge']")
        seen_tags = set()
        tags: List[str] = []
        for t in tag_els:
            txt = _txt(t)
            if 1 < len(txt) < 60 and txt.lower() not in seen_tags:
                seen_tags.add(txt.lower())
                tags.append(txt)
        d["tags"] = tags[:15]

        if d["title"] or d["url"] or d["jobad_id"]:
            cards.append(d)

    return cards


def parse_detail_page(html: str, url: str = "") -> dict:
    """Parse single job detail page — extra fields beyond listing card.

    Užitečné pro: kontaktní údaje firmy, full description, requirements, benefits."""
    soup = BeautifulSoup(html, "html.parser")
    d: dict = {"url": url, "title": "", "company": "", "description": "", "requirements": "",
               "benefits": "", "contact_email": "", "contact_phone": "", "company_url": ""}

    title_el = _select_first(soup, "h1", "[class*='Title'] h1, h1[class*='Title']")
    d["title"] = _txt(title_el)

    comp_el = _select_first(soup, "[class*='Company'] a", "[class*='Employer'] a", "h2 a")
    d["company"] = _txt(comp_el, 200)
    if comp_el and comp_el.has_attr("href"):
        href = comp_el["href"]
        if href.startswith("/"):
            href = "https://www.jobs.cz" + href
        d["company_url"] = href

    # Full description
    desc_el = _select_first(soup, "[class*='Description']", "[class*='JobDescription']", "main")
    d["description"] = _txt(desc_el, 5000)

    # Email + phone scrape from text
    text = soup.get_text(" ")
    emails = re.findall(r"[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}", text)
    if emails:
        d["contact_email"] = emails[0]
    phones = re.findall(r"(\+?\d{3}[\s\-]?\d{3}[\s\-]?\d{3}[\s\-]?\d{3})", text)
    if phones:
        d["contact_phone"] = phones[0]

    return d
