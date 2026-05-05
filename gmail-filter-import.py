#!/usr/bin/env python3
"""
Autonomous Gmail filter import via Camoufox + Safari cookie hijack.
Imports ~/Desktop/Codex/dopita-forward-gmail-filter.xml into Filip's Gmail.
"""
import os
import sys
import time

XML_PATH = os.path.expanduser("~/Desktop/Codex/dopita-forward-gmail-filter.xml")
GMAIL_FILTERS_URL = "https://mail.google.com/mail/u/0/#settings/filters"

if not os.path.exists(XML_PATH):
    sys.exit(f"XML missing: {XML_PATH}")

import browser_cookie3
from camoufox.sync_api import Camoufox

# Safari cookies
cj = browser_cookie3.safari()
cookies = []
for c in cj:
    if any(d in c.domain for d in ('google.com', 'gstatic.com', 'googleapis.com')):
        try:
            cookies.append({
                'name': c.name,
                'value': c.value,
                'domain': c.domain if c.domain.startswith('.') else c.domain,
                'path': c.path or '/',
                'expires': int(c.expires) if c.expires else -1,
                'secure': bool(c.secure),
                'httpOnly': bool(getattr(c, '_rest', {}).get('HttpOnly', False)),
                'sameSite': 'Lax',
            })
        except Exception as e:
            print(f"  skip {c.domain}/{c.name}: {e}")

print(f"[*] Injecting {len(cookies)} Google cookies into Camoufox session")

with Camoufox(headless=False, humanize=False, locale=['cs-CZ', 'en-US']) as browser:
    context = browser.new_context()
    context.add_cookies(cookies)
    page = context.new_page()
    page.set_default_timeout(30000)

    print(f"[*] Navigating to {GMAIL_FILTERS_URL}")
    page.goto(GMAIL_FILTERS_URL, wait_until='domcontentloaded')
    time.sleep(5)

    if 'accounts.google.com' in page.url or 'signin' in page.url.lower():
        print(f"[X] NOT authenticated — redirected to {page.url}")
        page.screenshot(path='/tmp/gmail-auth-fail.png')
        sys.exit(1)

    print(f"[+] Authenticated. URL: {page.url}")
    print(f"[+] Title: {page.title()}")

    # Gmail SPA never goes networkidle. Wait for filter table heading via text.
    print("[*] Waiting for Filters section to render...")
    try:
        page.wait_for_selector('text=/Filtry|Filters/i', timeout=15000)
    except Exception:
        pass
    time.sleep(4)

    page.screenshot(path='/tmp/gmail-filters-page.png')
    print("[*] Screenshot: /tmp/gmail-filters-page.png")

    # Look for "Importovat filtry" link
    print("[*] Looking for Import filters link...")
    candidates = ["Importovat filtry", "Import filters", "Importovat", "Import"]
    import_link = None
    for txt in candidates:
        try:
            loc = page.get_by_text(txt, exact=True).first
            if loc.count() > 0 and loc.is_visible(timeout=2000):
                import_link = loc
                print(f"[+] Found Import link: '{txt}'")
                break
        except Exception:
            continue

    if not import_link:
        # fallback: search all links
        all_links = page.locator('a').all()
        for link in all_links:
            try:
                text = link.text_content() or ""
                if 'mportovat' in text or 'mport filter' in text.lower():
                    import_link = link
                    print(f"[+] Found Import link (fallback): '{text}'")
                    break
            except Exception:
                continue

    if not import_link:
        page.screenshot(path='/tmp/gmail-no-import.png')
        sys.exit("[X] Import filters link not found — check /tmp/gmail-no-import.png")

    import_link.scroll_into_view_if_needed()
    time.sleep(1)
    import_link.click()
    time.sleep(3)

    page.screenshot(path='/tmp/gmail-import-clicked.png')

    # File input now visible
    print("[*] Setting file input...")
    file_inputs = page.locator('input[type="file"]').all()
    if not file_inputs:
        sys.exit("[X] No file input found after clicking Import")

    file_inputs[0].set_input_files(XML_PATH)
    time.sleep(2)

    page.screenshot(path='/tmp/gmail-file-set.png')

    # Click "Otevřít soubor" / "Open file"
    print("[*] Looking for Open file button...")
    open_candidates = ["Otevřít soubor", "Open file", "Otevřít", "Open"]
    open_btn = None
    for txt in open_candidates:
        try:
            loc = page.get_by_role('button', name=txt).first
            if loc.count() > 0 and loc.is_visible(timeout=2000):
                open_btn = loc
                print(f"[+] Found Open button: '{txt}'")
                break
        except Exception:
            continue

    if open_btn:
        open_btn.click()
        time.sleep(4)

    page.screenshot(path='/tmp/gmail-after-open.png')

    # Check the "Apply to matching conversations" checkbox
    print("[*] Looking for Apply checkbox...")
    apply_candidates = [
        "Použít nový filtr na odpovídající konverzace",
        "Použít nový filtr",
        "Apply new filter to matching conversations",
        "Apply",
    ]
    for txt in apply_candidates:
        try:
            label = page.get_by_text(txt, exact=False).first
            if label.count() > 0 and label.is_visible(timeout=2000):
                # find associated checkbox
                cb = label.locator('xpath=preceding-sibling::input | xpath=following-sibling::input | xpath=ancestor::label/input | xpath=parent::*//input[@type="checkbox"]').first
                if cb.count() > 0:
                    cb.check()
                else:
                    label.click()
                print(f"[+] Toggled apply checkbox via: '{txt}'")
                time.sleep(1)
                break
        except Exception as e:
            print(f"  apply attempt '{txt}' failed: {e}")
            continue

    # Click "Vytvořit filtry" / "Create filters"
    print("[*] Looking for Create filters button...")
    create_candidates = ["Vytvořit filtry", "Create filters", "Vytvořit filtr", "Create filter"]
    create_btn = None
    for txt in create_candidates:
        try:
            loc = page.get_by_role('button', name=txt).first
            if loc.count() > 0 and loc.is_visible(timeout=2000):
                create_btn = loc
                print(f"[+] Found Create button: '{txt}'")
                break
        except Exception:
            continue

    if not create_btn:
        # fallback: any button with create text
        for btn in page.locator('button, div[role=button]').all():
            try:
                text = btn.text_content() or ""
                if 'vytvořit' in text.lower() or 'create filter' in text.lower():
                    create_btn = btn
                    print(f"[+] Found Create (fallback): '{text}'")
                    break
            except Exception:
                continue

    if create_btn:
        create_btn.click()
        time.sleep(5)
        page.screenshot(path='/tmp/gmail-after-create.png')
        print("[+] Filters CREATED")
    else:
        page.screenshot(path='/tmp/gmail-no-create.png')
        print("[X] Create button not found — check /tmp/gmail-no-create.png")

    print(f"\n[+] Final URL: {page.url}")
    print(f"[+] Final title: {page.title()}")

    # Keep window open 5s for visual confirmation
    time.sleep(5)
