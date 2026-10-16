# Vikunja

Self-hosted task manager, reachable only over Tailscale. Chose the
single combined `vikunja/vikunja` image (API + frontend in one
container, SQLite database) over a split api/frontend/Postgres setup —
this is a single-household install, not a scale concern, and SQLite
avoids introducing the first database container on this box.

## Why its own `tailscale serve` port, not routed through Caddy

Every other web-UI service here that's just HTTP (Forgejo) goes through
Caddy. Vikunja doesn't, deliberately: its own docs say running it from
a subdirectory "is not supported out of the box" — it needs a custom
frontend build (`VIKUNJA_FRONTEND_BASE` set at `pnpm run build` time)
and a custom API binary, not just a reverse-proxy path rule. Rather
than maintain a custom image build for this, it gets its own dedicated
origin — same pattern as CryptPad's `:8443`/`:8444` — at **port 8445**.

Checked before committing to this: Vikunja clients (web, desktop,
mobile) only ever need one address, the instance's base URL — they
append `/api/v1` themselves. No separate "API URL" field to configure
unless you deliberately split frontend and API onto different
subdomains (that path hits CORS issues per the Vikunja community forum
— not done here).

## How it's wired

- `VIKUNJA_SERVICE_PUBLICURL=https://6l.seahorse-enigmatic.ts.net:8445/`
  — must match the exact URL users reach it through, or the frontend
  loads but can't reach its own API.
- Container listens on `127.0.0.1:3456` only — not reachable from the
  LAN at any layer except through `tailscale serve`.
- `VIKUNJA_SERVICE_ENABLEREGISTRATION=false` — household install, not
  open signup (same posture as Forgejo's `DISABLE_REGISTRATION`).
- `VIKUNJA_SERVICE_SECRET` (the JWT signing secret) lives in
  `~/services/state/vikunja/secret.env`, outside the repo — generated
  once with `openssl rand -hex 32`, loaded via `env_file:` in
  `docker-compose.yml`. **Not committed anywhere.**

## Setup

```bash
mkdir -p ~/services/state/vikunja/{files,db}
openssl rand -hex 32 | sed 's/^/VIKUNJA_SERVICE_SECRET=/' > ~/services/state/vikunja/secret.env
chmod 600 ~/services/state/vikunja/secret.env

docker compose -f ~/code/homelab/services/vikunja/docker-compose.yml up -d

# One-time, needs sudo + a real TTY (sudo can't authenticate through a
# non-interactive session):
sudo tailscale serve --bg --https=8445 http://127.0.0.1:3456
```

Check current state any time with `tailscale serve status`.

Verify: `curl -sk https://6l.seahorse-enigmatic.ts.net:8445/api/v1/info`
should return JSON (version, frontend_url, etc.) — confirms the full
chain (tailscale serve → container → SQLite) before ever opening a
client. **Live as of 2026-10-16** — verified this way.

## Data

`~/services/state/vikunja/`:
- `db/vikunja.db` — SQLite database, everything (tasks, users, auth).
- `files/` — task attachments.
- `secret.env` — JWT secret, see above. Back up `db/` and `files/`
  together; losing `secret.env` alone just invalidates existing
  sessions/tokens, not data.

## Port

`3456` internally (localhost-only). Externally, `8445` via
`tailscale serve` — tailnet-only, same as every other service here.
