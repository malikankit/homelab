#!/usr/bin/env python3
"""
Download the Vimeo video embedded in a dojo-trading.com article, using a
saved login session (see login.py).

Usage:
    python3 download.py <article_url> [--out-dir downloads] [--session session.json]

Example:
    python3 download.py \\
        https://dojo-trading.com/library/article/24-08-2026-weekly-market-update-9620b4
"""
import argparse
import re
import subprocess
import sys
from pathlib import Path
from urllib.parse import urlparse

from playwright.sync_api import sync_playwright

HERE = Path(__file__).parent

# Matches player.vimeo.com/video/<id> embed URLs, including any query
# string (Vimeo often puts an access hash like ?h=xxxxxxxxxx there for
# unlisted/domain-restricted videos - we need that hash to download).
VIMEO_URL_RE = re.compile(
    r"https?://player\.vimeo\.com/video/\d+[^\s\"'<>]*"
)


def find_vimeo_url(page) -> str | None:
    # 1. Check iframe src/data-src attributes directly (most reliable).
    for iframe in page.query_selector_all("iframe"):
        for attr in ("src", "data-src"):
            val = iframe.get_attribute(attr)
            if val and "player.vimeo.com/video/" in val:
                return val if val.startswith("http") else f"https:{val}"

    # 2. Fall back to scanning the full page HTML/JS for the URL pattern
    #    (covers players constructed via JS instead of a plain iframe).
    html = page.content()
    match = VIMEO_URL_RE.search(html)
    if match:
        return match.group(0)

    return None


def slugify(url: str) -> str:
    path = urlparse(url).path.rstrip("/")
    slug = path.rsplit("/", 1)[-1] or "video"
    return re.sub(r"[^a-zA-Z0-9._-]+", "-", slug)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("article_url")
    parser.add_argument("--out-dir", default=str(HERE / "downloads"))
    parser.add_argument("--session", default=str(HERE / "session.json"))
    args = parser.parse_args()

    session_path = Path(args.session)
    if not session_path.exists():
        print(f"No session file at {session_path}.", file=sys.stderr)
        print("Run login.py first to create one.", file=sys.stderr)
        sys.exit(1)

    out_dir = Path(args.out_dir)
    out_dir.mkdir(parents=True, exist_ok=True)

    print(f"Loading article: {args.article_url}")
    with sync_playwright() as p:
        browser = p.chromium.launch(headless=True)
        context = browser.new_context(storage_state=str(session_path))
        page = context.new_page()
        page.goto(args.article_url, wait_until="networkidle")

        vimeo_url = find_vimeo_url(page)
        browser.close()

    if not vimeo_url:
        print(
            "Could not find a Vimeo embed on that page. "
            "The session may have expired (re-run login.py) or the page "
            "structure differs from what this script expects.",
            file=sys.stderr,
        )
        sys.exit(1)

    print(f"Found Vimeo video: {vimeo_url}")

    slug = slugify(args.article_url)
    out_template = str(out_dir / f"{slug}.%(ext)s")

    # --referer is required: Vimeo embeds used this way are typically
    # domain-restricted, so yt-dlp must present the article page as the
    # referer or Vimeo will refuse to serve the video.
    cmd = [
        "yt-dlp",
        "--referer",
        args.article_url,
        "-o",
        out_template,
        vimeo_url,
    ]
    print("Running:", " ".join(cmd))
    result = subprocess.run(cmd)
    sys.exit(result.returncode)


if __name__ == "__main__":
    main()
