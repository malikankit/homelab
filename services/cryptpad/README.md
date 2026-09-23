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
dedicated `tailscale serve` ports rather than going through Caddy:

- **Main UI** (`httpUnsafeOrigin`): `https://6l.seahorse-enigmatic.ts.net:8443/`
  → `tailscale serve --https=8443` → `127.0.0.1:3010` → container's
  internal port 3000.
- **Sandbox** (`httpSafeOrigin`): `https://6l.seahorse-enigmatic.ts.net:8444/`
  → `tailscale serve --https=8444` → `127.0.0.1:3011` → container's
  internal port 3001.

Host-side ports are 3010/3011, not CryptPad's default 3000/3001 —
3000 is already taken by Forgejo's web UI on this host.

## Setup

```bash
mkdir -p ~/services/state/cryptpad/{blob,block,data,files,customize}
docker compose -f ~/code/homelab/services/cryptpad/docker-compose.yml up -d
sudo tailscale serve --bg --https=8443 http://127.0.0.1:3010
sudo tailscale serve --bg --https=8444 http://127.0.0.1:3011
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
