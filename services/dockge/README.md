# Dockge

Compose-native container management UI for geekom — no lock-in, stacks
are plain `docker-compose.yml` files under `./stacks/`.

## Access

Bound to `127.0.0.1:5001` only — **not** exposed over Tailscale. Dockge
has full Docker-socket access (equivalent to root on this machine), so
it's treated as a local-only admin tool rather than a tailnet-reachable
service. Reach it either:

- Directly on geekom's own desktop, browse to `http://localhost:5001`
- Remotely via an SSH tunnel:
  `ssh -L 5001:localhost:5001 am@100.78.110.5` then browse to
  `http://localhost:5001` on your own machine

## Setup

```bash
cd services/dockge
docker compose up -d
```

First visit to `http://localhost:5001` prompts you to create the admin
account.

## Data / backup

- `./data/` — Dockge's own app data (accounts, settings)
- `./stacks/` — every compose stack Dockge manages (including this
  homelab's Forgejo/Caddy stacks, once deployed through it) lives here
  as plain files, not a database — back up by copying this directory.

## Port

`5001` (UI), localhost-only per above.
