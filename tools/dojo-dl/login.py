#!/usr/bin/env python3
"""
One-time (or occasional) interactive login for dojo-trading.com.

Opens a real, visible browser window. You log in by hand (this handles
2FA/captcha fine since a human is doing it). Once you're logged in and
can see your account/library, come back to the terminal and press Enter
- the script saves the browser's cookies + local storage to session.json
so download.py can reuse them without you logging in again.

Usage:
    python3 login.py [start_url]

start_url defaults to https://dojo-trading.com/login
"""
import sys
from pathlib import Path

from playwright.sync_api import sync_playwright

SESSION_FILE = Path(__file__).parent / "session.json"
DEFAULT_START_URL = "https://dojo-trading.com/login"


def main() -> None:
    start_url = sys.argv[1] if len(sys.argv) > 1 else DEFAULT_START_URL

    with sync_playwright() as p:
        browser = p.chromium.launch(headless=False)
        context = browser.new_context()
        page = context.new_page()
        page.goto(start_url)

        print()
        print("A browser window has opened.")
        print("Log in to dojo-trading.com as you normally would.")
        print("Once you're logged in (e.g. you can see the library), come back")
        print("here and press Enter to save the session.")
        input()

        context.storage_state(path=str(SESSION_FILE))
        browser.close()

    print(f"Saved session to {SESSION_FILE}")
    print("You can now run download.py with an article URL.")


if __name__ == "__main__":
    main()
