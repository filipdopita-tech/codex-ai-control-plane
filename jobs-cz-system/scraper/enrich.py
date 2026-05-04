"""Enrichment helpers — detail page contact scrape + ARES IČO lookup pro firmy.

Detail enrichment:  použito jen na top-score listings (default 10) aby se nezatěžoval scrape čas.
ARES enrichment:    bezplatný CZ register firem (https://ares.gov.cz) — IČO, sídlo, NACE, status."""
from __future__ import annotations

import json
import re
import time
import urllib.parse
import urllib.request
from pathlib import Path
from typing import Dict, List, Optional

ARES_API = "https://ares.gov.cz/ekonomicke-subjekty-v-be/rest/ekonomicke-subjekty/vyhledat"
ARES_DETAIL = "https://ares.gov.cz/ekonomicke-subjekty-v-be/rest/ekonomicke-subjekty/{ico}"


# ---------- Detail page enrichment (top listings) ----------

def enrich_detail_top(cards: List[dict], session_path: str, limit: int = 10) -> List[dict]:
    """Pro top N karet (podle _score) navštív detail URL, vytahni email/phone/popis.

    Modifikuje cards in-place. Vrací modified list."""
    from playwright.sync_api import sync_playwright
    from .parser import parse_detail_page

    enriched = sorted(cards, key=lambda x: -x.get("_score", 0))[:limit]
    if not enriched:
        return cards

    with sync_playwright() as p:
        b = p.chromium.launch(headless=True, args=["--no-sandbox", "--disable-dev-shm-usage"])
        ctx_kwargs = dict(locale="cs-CZ", timezone_id="Europe/Prague",
                          user_agent="Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 "
                                     "(KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36",
                          viewport={"width": 1366, "height": 900})
        if Path(session_path).exists():
            ctx_kwargs["storage_state"] = session_path
        ctx = b.new_context(**ctx_kwargs)
        page = ctx.new_page()

        for c in enriched:
            url = c.get("url", "")
            if not url:
                continue
            try:
                page.goto(url, wait_until="domcontentloaded", timeout=20000)
                time.sleep(1.5)
                detail = parse_detail_page(page.content(), url=url)
                if detail.get("contact_email"):
                    c["contact_email"] = detail["contact_email"]
                if detail.get("contact_phone"):
                    c["contact_phone"] = detail["contact_phone"]
                if detail.get("description"):
                    c["description"] = detail["description"]
                if detail.get("company_url"):
                    c["company_url"] = detail["company_url"]
            except Exception as e:
                c["_enrich_error"] = str(e)[:200]
                continue
        b.close()
    return cards


# ---------- ARES IČO enrichment ----------

def _http_get_json(url: str, timeout: float = 10.0) -> Optional[dict]:
    req = urllib.request.Request(url, headers={"User-Agent": "OneFlow-Jobs-Scraper/1.0", "Accept": "application/json"})
    try:
        with urllib.request.urlopen(req, timeout=timeout) as r:
            return json.loads(r.read().decode("utf-8"))
    except Exception:
        return None


def search_ares_by_company(name: str) -> List[dict]:
    """Vyhledá firmu v ARES podle obchodního názvu. Vrací max 5 hits."""
    if not name or len(name) < 3:
        return []
    body = {"obchodniJmeno": name, "pocet": 5}
    data = json.dumps(body).encode("utf-8")
    req = urllib.request.Request(
        ARES_API,
        data=data,
        headers={"User-Agent": "OneFlow-Jobs-Scraper/1.0", "Accept": "application/json", "Content-Type": "application/json"},
        method="POST",
    )
    try:
        with urllib.request.urlopen(req, timeout=10) as r:
            payload = json.loads(r.read().decode("utf-8"))
            return payload.get("ekonomickeSubjekty", []) or []
    except Exception:
        return []


def get_ares_detail(ico: str) -> Optional[dict]:
    """Detailní data z ARES podle IČO."""
    if not re.match(r"^\d{6,8}$", ico or ""):
        return None
    return _http_get_json(ARES_DETAIL.format(ico=ico))


def enrich_leads_with_ares(leads: List[dict], polite_delay: float = 0.4) -> List[dict]:
    """Pro každý lead row přidej ARES data: ico, sídlo, NACE, právní forma, datum vzniku, status."""
    out = []
    for lead in leads:
        co_name = (lead.get("company") or "").strip()
        # Strip s.r.o. / a.s. / atd. pro lepší match
        clean = re.sub(r"\s*(s\.?\s?r\.?\s?o\.?|a\.?\s?s\.?|spol\.?\s+s\s+r\.?\s?o\.?|k\.?\s?s\.?|v\.?\s?o\.?\s?s\.?)\s*$", "", co_name, flags=re.I).strip()
        hits = search_ares_by_company(clean) if clean else []
        time.sleep(polite_delay)
        if hits:
            best = hits[0]
            sidlo = best.get("sidlo") or {}
            lead["ares_ico"] = best.get("ico", "")
            lead["ares_dic"] = best.get("dic", "")
            lead["ares_obchodni_jmeno"] = best.get("obchodniJmeno", "")
            lead["ares_pravni_forma"] = best.get("pravniForma", "")
            lead["ares_datum_vzniku"] = best.get("datumVzniku", "")
            lead["ares_sidlo"] = " ".join(filter(None, [
                sidlo.get("ulice", ""),
                str(sidlo.get("cisloDomovni", "") or ""),
                sidlo.get("nazevObce", ""),
                str(sidlo.get("psc", "") or ""),
            ])).strip()
            cinnosti = best.get("czNace", []) or []
            lead["ares_nace"] = ",".join(cinnosti[:3])
            lead["ares_match_count"] = len(hits)
        else:
            lead["ares_ico"] = ""
            lead["ares_match_count"] = 0
        out.append(lead)
    return out
