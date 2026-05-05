#!/usr/bin/env python3
"""Move all current Spam folder content (matching dopita filters) to Inbox via Camoufox."""
import os, sys, time
import browser_cookie3
from camoufox.sync_api import Camoufox

cj = browser_cookie3.safari()
cookies = []
for c in cj:
    if any(d in c.domain for d in ('google.com', 'gstatic.com', 'googleapis.com')):
        try:
            cookies.append({
                'name': c.name, 'value': c.value,
                'domain': c.domain, 'path': c.path or '/',
                'expires': int(c.expires) if c.expires else -1,
                'secure': bool(c.secure),
                'httpOnly': False, 'sameSite': 'Lax',
            })
        except Exception:
            pass

print(f"[*] {len(cookies)} cookies loaded")

with Camoufox(headless=False, humanize=False, locale=['cs-CZ', 'en-US']) as browser:
    context = browser.new_context()
    context.add_cookies(cookies)
    page = context.new_page()
    page.set_default_timeout(30000)

    # Filter — only dopita-tagged or forward-chain mail
    SPAM_QUERIES = [
        "in:spam (to:dopita@oneflow.cz OR from:@oneflow.cz OR from:SRS0= OR label:dopita-oneflow-cz)",
    ]

    moved_total = 0
    for q in SPAM_QUERIES:
        # Use Gmail search URL (in:spam scoped query)
        encoded = q.replace(' ', '+').replace(':', '%3A').replace('@', '%40').replace('(', '%28').replace(')', '%29')
        url = f"https://mail.google.com/mail/u/0/#search/{encoded}"
        print(f"\n[*] Query: {q}")

        for cycle in range(10):
            page.goto(url, wait_until='domcontentloaded')
            time.sleep(6)

            # Find threads
            checkboxes = page.locator('tr div[role="checkbox"][aria-checked="false"]').all()
            visible_unchecked = []
            for cb in checkboxes:
                try:
                    if cb.is_visible(timeout=300):
                        visible_unchecked.append(cb)
                except Exception:
                    pass

            if not visible_unchecked:
                print(f"  [+] cycle {cycle}: 0 threads — done")
                break

            print(f"  [*] cycle {cycle}: {len(visible_unchecked)} thread rows")

            # Click each visible checkbox (select)
            clicked = 0
            for cb in visible_unchecked:
                try:
                    cb.click(timeout=1500)
                    clicked += 1
                    time.sleep(0.03)
                except Exception:
                    pass
            time.sleep(1)
            print(f"  [+] selected {clicked}")

            # In Gmail search view (in:spam result), look for "Není spam" via aria-label of toolbar buttons
            # Gmail uses div[role=button] with data-tooltip and aria-label
            not_spam_clicked = False

            # Strategy 1: aria-label match
            selectors_to_try = [
                'div[role="button"][aria-label="Není spam"]',
                'div[role="button"][aria-label="Not spam"]',
                'div[role="button"][data-tooltip="Není spam"]',
                'div[role="button"][data-tooltip="Not spam"]',
                'div[aria-label*="Není spam"]',
                'div[data-tooltip*="Není spam"]',
            ]
            for sel in selectors_to_try:
                try:
                    btn = page.locator(sel).first
                    if btn.count() > 0 and btn.is_visible(timeout=1500):
                        btn.click(timeout=2000)
                        not_spam_clicked = True
                        print(f"  [+] clicked Není spam via: {sel}")
                        time.sleep(4)
                        break
                except Exception:
                    continue

            # Strategy 2: keyboard shortcut for "report not spam" — Gmail has Shift+! to toggle spam
            # Or use undo spam: keyboard shortcut '!' marks as spam, no inverse shortcut by default

            if not not_spam_clicked:
                # Strategy 3: open the kebab menu (More) and find "Označit jako není spam"
                try:
                    more_btn = page.locator('div[role="button"][aria-label="Další"], div[role="button"][aria-label="More"]').first
                    if more_btn.count() > 0 and more_btn.is_visible(timeout=1500):
                        more_btn.click()
                        time.sleep(1)
                        for txt in ["Označit jako není spam", "Mark as not spam", "Není spam", "Not spam"]:
                            try:
                                item = page.get_by_role('menuitem', name=txt).first
                                if item.count() > 0 and item.is_visible(timeout=1500):
                                    item.click()
                                    not_spam_clicked = True
                                    print(f"  [+] clicked menu item: {txt}")
                                    time.sleep(4)
                                    break
                            except Exception:
                                continue
                except Exception as e:
                    print(f"  [-] More menu failed: {e}")

            if not not_spam_clicked:
                page.screenshot(path=f'/tmp/gmail-cleanup-cycle{cycle}-stuck.png')
                print(f"  [X] cycle {cycle}: button not found, screenshot saved")
                # Dump visible toolbar buttons for debug
                btns = page.locator('div[role="button"][aria-label]').all()
                tooltips = []
                for b in btns[:30]:
                    try:
                        if b.is_visible(timeout=200):
                            tooltips.append(b.get_attribute('aria-label'))
                    except Exception:
                        pass
                print(f"  [debug] toolbar buttons visible: {tooltips[:15]}")
                break

            moved_total += clicked

    print(f"\n[+] Total moved out of spam: ~{moved_total}")
    page.screenshot(path='/tmp/gmail-cleanup-final.png')
    time.sleep(3)
