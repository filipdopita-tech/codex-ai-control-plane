#!/usr/bin/env python3
"""
jobs.cz login + persistent session capture
Runs on Flash VPS. Saves storage_state for reuse by future scrapers.

Usage:
    /root/.venvs/jobs-cz/bin/python /root/jobs-cz/login.py

Output:
    /root/.credentials/jobs_cz_session.json  (storage_state — cookies + localStorage)
    /root/jobs-cz/screenshots/  (debug screenshots)
"""
import os
import sys
import time
from pathlib import Path
from playwright.sync_api import sync_playwright, TimeoutError as PWTimeout

CREDS = Path("/root/.credentials/jobs_cz.env")
OUT_SESSION = Path("/root/.credentials/jobs_cz_session.json")
OUT_SCREENS = Path("/root/jobs-cz/screenshots")
OUT_SCREENS.mkdir(parents=True, exist_ok=True)


def load_creds():
    env = {}
    for line in CREDS.read_text().splitlines():
        line = line.strip()
        if not line or line.startswith("#"):
            continue
        k, _, v = line.partition("=")
        env[k.strip()] = v.strip().strip('"').strip("'")
    return env


def screenshot(page, name):
    p = OUT_SCREENS / f"{int(time.time())}_{name}.png"
    page.screenshot(path=str(p), full_page=True)
    print(f"  [screenshot] {p}")
    return p


def main():
    env = load_creds()
    login = env["JOBS_CZ_LOGIN"]
    password = env["JOBS_CZ_PASSWORD"]
    login_url = env.get("JOBS_CZ_LOGIN_URL", "https://www.jobs.cz/uzivatel/prihlaseni/")

    print(f"[1/7] Loaded creds for {login}")

    with sync_playwright() as p:
        browser = p.chromium.launch(
            headless=True,
            args=[
                "--disable-blink-features=AutomationControlled",
                "--no-sandbox",
                "--disable-dev-shm-usage",
            ],
        )
        context = browser.new_context(
            viewport={"width": 1366, "height": 900},
            user_agent="Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36",
            locale="cs-CZ",
            timezone_id="Europe/Prague",
        )

        # Mask navigator.webdriver
        context.add_init_script(
            """
            Object.defineProperty(navigator, 'webdriver', { get: () => undefined });
            Object.defineProperty(navigator, 'languages', { get: () => ['cs-CZ', 'cs', 'en'] });
            """
        )

        page = context.new_page()

        print(f"[2/7] Navigating to {login_url}")
        try:
            page.goto(login_url, wait_until="domcontentloaded", timeout=30000)
        except PWTimeout:
            print("  [WARN] domcontentloaded timeout — continuing")
        time.sleep(2)
        screenshot(page, "01_login_page")

        # Handle cookie consent if present
        print("[3/7] Cookie consent")
        for selector in [
            'button:has-text("Přijmout vše")',
            'button:has-text("Souhlasím")',
            'button:has-text("Rozumím")',
            'button:has-text("Accept all")',
            '[data-testid="cookie-accept"]',
            '#cookiescript_accept',
        ]:
            try:
                btn = page.locator(selector).first
                if btn.is_visible(timeout=2000):
                    btn.click()
                    print(f"  [click] {selector}")
                    time.sleep(1)
                    break
            except Exception:
                pass

        screenshot(page, "02_after_consent")

        # Detect email + password fields
        print("[4/7] Detecting form fields")
        # Try standard selectors first
        email_selectors = [
            'input[type="email"]',
            'input[name="email"]',
            'input[name="username"]',
            'input[id*="email" i]',
            'input[id*="login" i]',
            'input[autocomplete="email"]',
            'input[autocomplete="username"]',
        ]
        pwd_selectors = [
            'input[type="password"]',
            'input[name="password"]',
            'input[autocomplete="current-password"]',
        ]

        email_loc = None
        for sel in email_selectors:
            try:
                loc = page.locator(sel).first
                if loc.count() > 0 and loc.is_visible(timeout=1500):
                    email_loc = loc
                    print(f"  [email] {sel}")
                    break
            except Exception:
                continue

        pwd_loc = None
        for sel in pwd_selectors:
            try:
                loc = page.locator(sel).first
                if loc.count() > 0 and loc.is_visible(timeout=1500):
                    pwd_loc = loc
                    print(f"  [pwd] {sel}")
                    break
            except Exception:
                continue

        if not email_loc:
            print("  [ERROR] No email field found")
            screenshot(page, "ERROR_no_email")
            print("\n  HTML snippet:")
            print(page.content()[:3000])
            browser.close()
            sys.exit(2)

        # Fill email first (some flows reveal pwd after email submit)
        print("[5/7] Filling credentials")
        email_loc.click()
        email_loc.fill(login)
        time.sleep(0.5)

        if not pwd_loc:
            # Try clicking continue/next button
            for sel in [
                'button:has-text("Pokračovat")',
                'button:has-text("Dále")',
                'button[type="submit"]',
            ]:
                try:
                    btn = page.locator(sel).first
                    if btn.is_visible(timeout=1000):
                        btn.click()
                        print(f"  [click continue] {sel}")
                        page.wait_for_load_state("domcontentloaded", timeout=10000)
                        time.sleep(2)
                        break
                except Exception:
                    continue

            # Re-detect password
            for sel in pwd_selectors:
                try:
                    loc = page.locator(sel).first
                    if loc.count() > 0 and loc.is_visible(timeout=2000):
                        pwd_loc = loc
                        print(f"  [pwd-late] {sel}")
                        break
                except Exception:
                    continue

        if not pwd_loc:
            print("  [ERROR] No password field after continue")
            screenshot(page, "ERROR_no_pwd")
            browser.close()
            sys.exit(3)

        pwd_loc.click()
        pwd_loc.fill(password)
        time.sleep(0.5)
        screenshot(page, "03_filled")

        # Submit
        print("[6/7] Submitting")
        submitted = False
        for sel in [
            'button[type="submit"]',
            'button:has-text("Přihlásit")',
            'button:has-text("Přihlásit se")',
            'input[type="submit"]',
        ]:
            try:
                btn = page.locator(sel).first
                if btn.is_visible(timeout=1000):
                    btn.click()
                    print(f"  [submit] {sel}")
                    submitted = True
                    break
            except Exception:
                continue

        if not submitted:
            pwd_loc.press("Enter")
            print("  [submit] Enter key fallback")

        # Wait for navigation / login completion
        try:
            page.wait_for_load_state("networkidle", timeout=20000)
        except PWTimeout:
            print("  [WARN] networkidle timeout — continuing")
        time.sleep(3)
        screenshot(page, "04_after_submit")

        current_url = page.url
        print(f"  [url after submit] {current_url}")

        # Detect login result
        # Success heuristics: URL change away from login page, presence of logout link, profile element
        page_text = page.content().lower()
        success_signals = [
            "odhlásit" in page_text,
            "logout" in page_text,
            "muj profil" in page_text,
            "můj profil" in page_text,
            "moje" in page_text and "uzivatel/prihlaseni" not in current_url,
        ]
        failure_signals = [
            "nesprávné" in page_text,
            "incorrect" in page_text,
            "neplatné" in page_text,
            "captcha" in page_text,
            "robot" in page_text,
        ]

        print(f"  [signals] success={sum(success_signals)} fail={sum(failure_signals)}")

        # Verify by visiting profile/dashboard
        print("[7/7] Verifying — visiting profile area")
        try:
            page.goto("https://www.jobs.cz/uzivatel/", wait_until="domcontentloaded", timeout=15000)
            time.sleep(2)
            screenshot(page, "05_profile")
            verify_url = page.url
            verify_text = page.content().lower()
            authenticated = (
                "odhlásit" in verify_text
                or "logout" in verify_text
                or "muj profil" in verify_text
                or "můj profil" in verify_text
            ) and "uzivatel/prihlaseni" not in verify_url
            print(f"  [verify url] {verify_url}")
            print(f"  [authenticated] {authenticated}")
        except Exception as e:
            print(f"  [verify error] {e}")
            authenticated = False

        # Save session regardless (so Filip can debug + reuse)
        context.storage_state(path=str(OUT_SESSION))
        OUT_SESSION.chmod(0o600)
        print(f"\n  [session saved] {OUT_SESSION} ({OUT_SESSION.stat().st_size} bytes)")

        browser.close()

        if authenticated:
            print("\n[OK] LOGIN SUCCESS — session persisted")
            sys.exit(0)
        else:
            print("\n[PARTIAL] Login submitted but verification inconclusive — check screenshots")
            sys.exit(1)


if __name__ == "__main__":
    main()
