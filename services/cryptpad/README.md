# CryptPad

Self-hosted, end-to-end-encrypted office suite (docs, spreadsheets,
presentations, kanban, whiteboard) for geekom — first of a 3-way
office-suite eval (OnlyOffice, Collabora CODE, CryptPad), tried here
first since it needs no companion service (unlike OnlyOffice/Collabora,
which pair with Nextcloud).

Runtime state (`~/services/state/cryptpad/` — `blob`, `block`, `data`,
`files`, `customize`) lives outside this repo, same convention as
Forgejo/Caddy/Dockge.

## Access

CryptPad needs two distinct origins for its own content-isolation model
(the main UI is treated as "unsafe," pad content is served from a
separate "safe"/sandboxed origin) — so unlike Forgejo, it gets two
dedicated `tailscale serve` ports rather than going through Caddy.

**Important**: with `httpSafeOrigin` configured (two real origins, as
opposed to CryptPad's single-domain dev-mode fallback), there is only
**one backend port** — the same Node server handles both origins,
distinguishing main vs. sandbox purely by the incoming request's Host
header. There's a *second* internal port too, but it's for websockets
only (`/cryptpad_websocket`), not a second sandbox port — CryptPad's own
docs are easy to misread here (the "httpPort+1 sandbox port" they
describe only applies when `httpSafeOrigin` is unset).

- **Main UI** (`httpUnsafeOrigin`): `https://6l.seahorse-enigmatic.ts.net:8443/`
- **Sandbox** (`httpSafeOrigin`): `https://6l.seahorse-enigmatic.ts.net:8444/`
- Both origins point at the **same** backend, `127.0.0.1:3010`
  (container's internal port 3000).
- Both origins also need `/cryptpad_websocket` forwarded separately to
  `127.0.0.1:3013` (container's internal port 3003) — real-time
  collaborative editing won't work without this.

Host-side ports are 3010/3013, not CryptPad's default 3000/3003 — 3000
is already taken by Forgejo's web UI on this host.

## Setup

```bash
mkdir -p ~/services/state/cryptpad/{blob,block,data,files,customize}
docker compose -f ~/code/homelab/services/cryptpad/docker-compose.yml up -d
sudo tailscale serve --bg --https=8443 http://127.0.0.1:3010
sudo tailscale serve --bg --https=8443 --set-path=/cryptpad_websocket http://127.0.0.1:3013
sudo tailscale serve --bg --https=8444 http://127.0.0.1:3010
sudo tailscale serve --bg --https=8444 --set-path=/cryptpad_websocket http://127.0.0.1:3013
```

First boot prints an install URL with a one-time token in
`docker compose logs cryptpad` (`https://.../install/#<token>`) — visit
it to create the admin account. Then, from Settings → Account, copy
your account's **public signing key** and add it to `adminKeys` in a
custom `config.js` if you want the admin panel (the env-var-only setup
here doesn't have an `adminKeys` entry yet — see "Known gotchas" below).
Once the admin account exists, close public registration from the admin
panel (Instance settings → registration).

## Login salt

Set once, before any user registers (per CryptPad's docs, this can't be
changed retroactively without invalidating existing accounts) — lives
at `~/services/state/cryptpad/customize/application_config.js` as
`AppConfig.loginSalt = '<value>'`. The value itself isn't recorded here
or anywhere in this repo — it's host-local state, same as any other
secret.

## Known gotchas (hit during initial setup)

- **`customize/application_config.js` must use the RequireJS/CommonJS
  module wrapper — a bare `AppConfig.loginSalt = '...'` throws
  `ReferenceError: AppConfig is not defined`.** `AppConfig` isn't a
  global; the stock `customize.dist/application_config.js` wraps it in
  `(() => { const factory = (AppConfig) => { ...; return AppConfig; };
  ...define(['/common/application_config_internal.js'], factory); })();`
  — `AppConfig` only exists as the parameter the module loader injects.
  This first version here skipped that wrapper (copied the docs'
  one-liner example verbatim, which is misleading out of context) and
  it broke the client boot entirely — the error appears early enough in
  the load sequence to hang the whole app on "loading," not just break
  the settings it configures. Fixed by using the real factory-function
  wrapper, keeping the same `loginSalt` value.
- **Browser-extension noise looks like a CryptPad bug but isn't.** A
  `Content-Security-Policy ... blocked WebAssembly ... injectedScript.bundle.js`
  error is a browser extension's own injected script getting blocked by
  the page's CSP — extension content scripts run in the page context and
  are subject to the same policy. Harmless, unrelated to CryptPad's own
  operation; don't chase it.
- **Don't map a second "sandbox port" (3001) — it doesn't exist in this
  mode.** The initial setup here wrongly mapped host `3011` → container
  `3001`, causing the sandbox origin (`:8444`) to reset every
  connection. CryptPad's docs describe a `httpPort+1` sandbox port, but
  that's *only* used when `httpSafeOrigin` is left unset (single-domain
  dev mode) — with a real `httpSafeOrigin` configured (our case), both
  origins are served by the one Node process on `httpPort` (3000),
  distinguished by the Host header. The actual second port that exists
  is for websockets (3003, `/cryptpad_websocket`) — both origins need
  that path forwarded to it separately, or real-time sync silently
  doesn't work even though the page loads.
- **`CPAD_CONF` must be set explicitly.** The image's
  `docker-entrypoint.sh` reads a `CPAD_CONF` env var for where to write
  the generated `config.js` — if it's unset, the script's `cp` runs with
  an empty destination and crash-loops (`cp: can't create ''`). Set to
  `/cryptpad/config/config.js`.
- **Don't bind-mount the whole `/cryptpad/config` directory.** Doing so
  hides the image's built-in `config.example.js` that the entrypoint
  copies from to generate a fresh config on each boot (the whole point
  of the `CPAD_MAIN_DOMAIN`/`CPAD_SANDBOX_DOMAIN` env-var path used
  here) — causes `cp: can't stat '.../config.example.js'`. This compose
  file deliberately does **not** mount `/cryptpad/config` at all.
- **Host state dirs need to be owned by UID 4001**, not the host's own
  UID — the image runs as its own `cryptpad` user (uid 4001, confirmed
  via `docker run --entrypoint /bin/sh ... id`), not root and not
  whatever `USER_UID`/`USER_GID` env vars Forgejo's image accepts
  (CryptPad's image has no equivalent). `chown -R 4001:4001` needs
  `sudo`, which wasn't available non-interactively when this was set
  up — used `chmod -R 777` on the state dirs instead as a pragmatic
  workaround (single-user host, state is CryptPad's own data, not
  otherwise sensitive to local permission boundaries). Revisit with a
  proper `chown 4001:4001` when doing this interactively.
- **`sudo tailscale serve` requires an interactive terminal** on this
  host — can't be run from an unattended/scripted session, same
  limitation already noted for the Forgejo/Caddy setup.
