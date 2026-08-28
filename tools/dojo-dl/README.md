# dojo-dl

Downloads the Vimeo video embedded in a dojo-trading.com weekly market
update article, using your own logged-in session. First step toward a
transcription pipeline built on top of the downloaded videos.

## Setup

```bash
cd tools/dojo-dl
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
playwright install chromium
```

`yt-dlp` also needs to be on your PATH (the pip package above installs a
`yt-dlp` console script into the venv, so this is automatic once the venv
is active).

## Usage

1. **Log in once** (opens a real browser window - log in by hand, handles
   2FA/captcha fine since you're the one doing it):

   ```bash
   python3 login.py
   ```

   Press Enter in the terminal once you're logged in. This saves
   `session.json` (gitignored - it's your live session, treat it like a
   password) for reuse by `download.py`.

2. **Download a video**:

   ```bash
   python3 download.py https://dojo-trading.com/library/article/24-08-2026-weekly-market-update-9620b4
   ```

   Saves to `downloads/<article-slug>.mp4` (also gitignored).

   If the session has expired, `download.py` will fail to find the video
   embed - just re-run `login.py`.

## How it works

- `login.py` uses Playwright to open a real browser, lets you log in
  manually, then saves cookies + local storage to `session.json`.
- `download.py` replays that session headlessly with Playwright, loads
  the article page, and scans it for the `player.vimeo.com/video/...`
  embed URL (including its access hash query param, needed for
  unlisted/domain-restricted Vimeo embeds).
- It then shells out to `yt-dlp`, passing the article URL as `--referer`
  since Vimeo checks the referer on domain-restricted embeds.

## Notes / things that may need adjusting

- `login.py` assumes the login page is at
  `https://dojo-trading.com/login` - pass a different start URL as an
  argument if the real login page lives elsewhere:
  `python3 login.py https://dojo-trading.com/some-other-login-path`
- If the site lazy-loads the video player (e.g. only after clicking
  "play"), `download.py`'s scrape may need to first click a play button
  before the iframe/URL appears in the page - not yet implemented, since
  it wasn't verified against the real page structure.
- Not yet handled: batch-downloading the whole `/library` listing (kept
  out of scope for this first pass - ask to add it if wanted).

## Next step: transcription

Once videos are downloading reliably, the plan is to feed them through a
transcription tool (e.g. `whisper`/`faster-whisper`) as a follow-up
pipeline stage.
