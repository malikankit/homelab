# CryptPad setup log

Everything done to bring up CryptPad on geekom — first of a 3-way
office-suite eval (CryptPad, OnlyOffice, Collabora CODE), tried first
since it needs no companion service. See `services/cryptpad/README.md`
for the condensed, "how to actually run this" version — this file is
the fuller narrative: every decision, every file, every bug hit and how
it was diagnosed, in the order it happened. Same convention as
`services/dockge_forgejo_caddy_setup_log.md`.

Tracked as an open item at `issues/office-suite-eval.md` until all
three candidates have been tried and one is picked for good.

---

## 1. Design decisions (locked in during planning, before any code)

Discussed and decided before touching geekom, alongside a broader
conversation about self-hosting more apps (Vaultwarden, Vikunja, an
office suite) and eventually inviting a second, less-trusted user onto
the AM tailnet:

- **Three candidates, tried in practice, not picked from description
  alone**: OnlyOffice Docs (best Excel-format fidelity, but pairs with
  Nextcloud and has a 2026 licensing controversy — mobile editing moved
  behind a paid `license.dat`), Collabora CODE (strong formula engine,
  fully open source, no known phone-home/licensing gate), CryptPad
  (lightest, fully self-contained, end-to-end encrypted, no companion
  service needed). CryptPad goes first.
- **Routing pattern for all future services: one dedicated `tailscale
  serve` port per service, not subdomains and not shared paths.**
  Subdomains don't work cleanly on a single Tailscale node (certs are
  minted per-device, not per-arbitrary-subdomain, without standing up a
  separate Tailscale node per service). Shared-path routing (behind
  Caddy on one port) can't be restricted per-service by a future
  Tailscale ACL policy, since ACLs only see `host:port`, not HTTP paths
  — and a Tailscale ACL policy is a known, currently-open gap (see
  `issues/tailscale-ufw-bypass-fix.md`; today's policy is default
  allow-all). This CryptPad install is the first real instance of that
  pattern.
- **ACL policy file itself stays out of scope** for this pass —
  separate follow-up once port numbers for all the new services are
  settled.
- **CryptPad specifically needs two real origins** for its own
  content-isolation model (an "unsafe" main UI origin, and a "safe"
  sandboxed origin pad content loads from) — ports `8443` (main) and
  `8444` (sandbox) on the existing `6l.seahorse-enigmatic.ts.net`
  hostname, going straight through `tailscale serve` rather than Caddy
  (Caddy's value is consolidating multiple services onto one
  path-routed port — doesn't apply here, CryptPad needs its own ports
  regardless).
- **State outside the repo**, same convention as Forgejo/Caddy/Dockge:
  `~/services/state/cryptpad/` holds the real data, git tracks only the
  compose file and README.

---

## 2. `services/cryptpad/docker-compose.yml` (created, then fixed twice)

Image pinned to `cryptpad/cryptpad:version-2026.5.1` (checked Docker
Hub's tag list directly rather than using `:latest`, matching the
version-pinning convention already used for Forgejo/Caddy/Dockge).

**First attempt** used host ports `3000:3000` and `3001:3001` — wrong
on both counts:

- `3000` was already bound by Forgejo's web UI on this host → container
  failed to start at all (`port is already allocated`). Fixed by
  remapping to `3010` host-side (container-internal port stays `3000`).
- `3001` was based on a misreading of CryptPad's own docs. Its
  `httpSafePort` ("httpPort + 1", i.e. 3001) is described as the
  sandbox port, but that's **only true when `httpSafeOrigin` is unset**
  (CryptPad's single-domain dev-mode fallback). Once a real
  `httpSafeOrigin` is configured — which is exactly what we're doing,
  giving it its own port 8444 — CryptPad runs **one backend** for both
  origins, distinguishing main vs. sandbox purely by the incoming
  request's Host header. Nothing ever listens on 3001 in this mode, so
  mapping it caused `Connection reset by peer` on every request to that
  port. Confirmed by reading `docker-entrypoint.sh` and the generated
  `config.js`'s inline comments directly, then checking what ports the
  Node process actually had open inside the container
  (`/proc/net/tcp`) — only `3000` and `3003` were listening, never
  `3001`.
- The *real* second port is `3003`, for **websockets**
  (`/cryptpad_websocket`) — confirmed against CryptPad's own
  `docs/example.nginx.conf`, which proxies `/cryptpad_websocket`
  specifically to port 3003 while everything else goes to 3000. Mapped
  host `3013` → container `3003`.

**Second fix**, hit on the very first `docker compose up`: the
container crash-looped with
```
cp: can't stat '/cryptpad/config/config.example.js': No such file or directory
```
The compose file originally bind-mounted the *entire*
`/cryptpad/config` directory from an empty host folder — which hid the
image's own built-in `config.example.js` that `docker-entrypoint.sh`
copies from to generate a fresh `config.js` on every boot (the whole
point of driving config via `CPAD_MAIN_DOMAIN`/`CPAD_SANDBOX_DOMAIN` env
vars instead of hand-editing `config.js`). Fixed by removing that mount
entirely — `config/` isn't mounted at all in the final version, only
`blob/`, `block/`, `data/`, `files/`, and `customize/`.

**Third fix**, same crash symptom's sibling —
```
cp: can't create '': No such file or directory
```
— after fixing the mount issue above. Traced by fetching
`docker-entrypoint.sh`'s actual source: it reads a `CPAD_CONF` env var
for *where* to write the generated config, and nothing sets a default
if it's missing — the script's `cp ... ""` then fails with an empty
destination. Added `CPAD_CONF=/cryptpad/config/config.js` to the
compose file's environment.

**Fourth fix**: `EACCES: permission denied` on `mkdir` inside the
container, for both `/cryptpad/customize/www` and `/cryptpad/data/logs`
— the image runs as its own internal user (confirmed via
`docker run --entrypoint /bin/sh cryptpad/cryptpad:version-2026.5.1 -c
'id'` → `uid=4001(cryptpad) gid=4001(cryptpad)`), not root, and not
matching the host's own uid/gid the way Forgejo's image does via
`USER_UID`/`USER_GID` env vars (CryptPad's image has no equivalent
knob). No passwordless `sudo` was available non-interactively to
`chown -R 4001:4001` the state directories, so used `chmod -R 777` on
`~/services/state/cryptpad/` as a pragmatic workaround — single-user
host, this is CryptPad's own data, not otherwise sensitive to local
permission boundaries. Flagged in the README as worth revisiting with a
proper `chown` next time it's convenient to run interactively.

Final working compose file:

```yaml
services:
  cryptpad:
    image: cryptpad/cryptpad:version-2026.5.1
    container_name: cryptpad
    restart: unless-stopped
    environment:
      - CPAD_MAIN_DOMAIN=https://6l.seahorse-enigmatic.ts.net:8443
      - CPAD_SANDBOX_DOMAIN=https://6l.seahorse-enigmatic.ts.net:8444
      - CPAD_CONF=/cryptpad/config/config.js
    volumes:
      - /home/am/services/state/cryptpad/blob:/cryptpad/blob
      - /home/am/services/state/cryptpad/block:/cryptpad/block
      - /home/am/services/state/cryptpad/data:/cryptpad/data
      - /home/am/services/state/cryptpad/files:/cryptpad/datastore
      - /home/am/services/state/cryptpad/customize:/cryptpad/customize
      - /etc/timezone:/etc/timezone:ro
      - /etc/localtime:/etc/localtime:ro
    ports:
      - "127.0.0.1:3010:3000"
      - "127.0.0.1:3013:3003"
```

---

## 3. `tailscale serve` wiring (manual — needs an interactive terminal)

Same limitation already logged for the Forgejo/Caddy setup: `sudo
tailscale serve` requires an interactive terminal, so this always has
to be handed to the user to run directly rather than executed from an
unattended session. Final 4 commands (main + websocket path, for both
origins):

```bash
sudo tailscale serve --bg --https=8443 http://127.0.0.1:3010
sudo tailscale serve --bg --https=8443 --set-path=/cryptpad_websocket http://127.0.0.1:3013
sudo tailscale serve --bg --https=8444 http://127.0.0.1:3010
sudo tailscale serve --bg --https=8444 --set-path=/cryptpad_websocket http://127.0.0.1:3013
```

Verified afterward with `tailscale serve status` and `curl`: main page
`HTTP 200` on both `:8443` and `:8444`, all referenced JS/CSS assets
`200`, and a real WebSocket upgrade handshake (`Connection: Upgrade`,
`Sec-WebSocket-Key`) returning `101 Switching Protocols` on both.

---

## 4. Login salt (`customize/application_config.js`) — set, then fixed

Per CryptPad's docs, a `loginSalt` should be set before any account
registers (it's mixed into the username+password key-derivation as an
instance-wide pepper — changing it after accounts exist would break
their derived encryption keys). Generated with `openssl rand -hex 16`
(128 bits from the system's CSPRNG) and written to
`~/services/state/cryptpad/customize/application_config.js`, which is
bind-mounted into the container.

**Bug, and the actual cause of the "stuck on loading" report**: the
first version of this file was:
```js
AppConfig.loginSalt = '<salt>';
```
copied too literally from CryptPad's one-line docs example. `AppConfig`
isn't a global in this file's scope — the stock
`customize.dist/application_config.js` template wraps everything in a
RequireJS/CommonJS module factory, where `AppConfig` only exists as the
parameter the module loader injects:
```js
(() => {
const factory = (AppConfig) => {
    AppConfig.loginSalt = '<salt>';
    return AppConfig;
};
if (typeof(module) !== 'undefined' && module.exports) {
    module.exports = factory(require('../www/common/application_config_internal.js'));
} else if ((typeof(define) !== 'undefined' && define !== null) && (define.amd !== null)) {
    define(['/common/application_config_internal.js'], factory);
}
})();
```
The bare version threw `Uncaught ReferenceError: AppConfig is not
defined` early enough in the client's RequireJS boot sequence
(`application_config.js` loads before the app shell finishes
initializing) to hang the whole page on its loading screen — not just
silently skip the salt setting. Diagnosed from the browser's own
Console tab output (the user pasted the exact error + file/line), not
from anything server-side — every `curl`-based check (HTTP 200s on the
page and every asset, valid TLS cert, successful WebSocket upgrade) had
already come back clean, which is what made this one hard to place
without the actual browser console.

Fixed by rewriting the file with the correct factory wrapper (same salt
value preserved), confirmed via `docker compose restart` +
re-`curl`-ing `/customize/application_config.js` that the server now
serves the corrected version.

**Also seen in the same console dump, and explicitly a red herring**: a
CSP violation from `injectedScript.bundle.js` trying to use
WebAssembly. That's a browser extension's own content script running in
the page and getting blocked by the page's `Content-Security-Policy` —
not a CryptPad bug, unrelated to the loading hang. Noted here so it
doesn't get re-investigated later.

**CSP architecture note** (context for the above, found while chasing
it): CryptPad serves two different CSP policies from
`lib/http-worker.js` / `lib/defaults.js` — a strict one (no
`unsafe-eval`, `unsafe-inline`, or `wasm-unsafe-eval`) for the main app
shell, and a looser one only for a hardcoded allowlist of paths
(`/sheet/inner.html`, `/presentation/inner.html`, `/doc/inner.html`,
`/unsafeiframe/inner.html`, plus an OnlyOffice spellcheck WASM path).
This is by design — crypto/WASM work is meant to happen inside those
specific sandboxed iframes, not the outer shell — and turned out to be
unrelated to our actual bug, but worth knowing if a future CSP error
shows up from inside an actual pad/sheet/doc rather than the shell.

---

## 5. Docs updated in the same batch

- `services/cryptpad/README.md` — setup steps, access/port model, and a
  "known gotchas" section covering every fix above.
- `HOMELAB.md` — new changelog entry (2026-09-23).
- `geekom/service_map.html` — new CryptPad node/edges, new port-table
  rows, container count bumped to 4 (per the standing `CLAUDE.md` rule
  to keep this diagram current whenever a Docker service changes).
- `geekom/early_journal.md` — narrative entry for today linking back
  here.
- `issues/office-suite-eval.md` — tracks the open part: confirm the
  fixed page actually loads end-to-end in a real browser, create the
  admin account, lock down registration, then repeat this whole
  exercise for OnlyOffice and Collabora CODE before picking one.

## Status as of this writing

Container healthy, ~844MB RSS. Server-side fully verified (HTTP, all
assets, WebSocket upgrade, corrected `application_config.js` all
serving `200`/`101` as expected). Not yet confirmed working end-to-end
in an actual browser after the `AppConfig` fix, no admin account
created yet, registration not yet locked down. See
`issues/office-suite-eval.md` for what's left.
