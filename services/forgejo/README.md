# Forgejo

Self-hosted git server (Forgejo, a Gitea fork) for geekom — Phase 1 of
`gitandansiblesetupplan.md`. Replaces GitHub for repos that don't need to
be public (starting with an Obsidian vault repo, via `obsidian-git`).

Runtime state (`~/services/state/forgejo/data/` — repos, DB, config,
SSH host keys) lives outside this repo entirely, same convention as
Dockge.

## Access

- **Web UI**: bound to `127.0.0.1:3000` only. Not directly reachable
  over Tailscale — `../caddy` reverse-proxies it and `tailscale serve`
  terminates TLS, so the real entry point is
  `https://6l.seahorse-enigmatic.ts.net/` once that's wired up.
- **git-over-SSH**: port `2222`, bound to geekom's own Tailscale IP
  (`100.78.110.5`), so any AM-tailnet device can reach it directly
  (same exposure model as the rest of this tailnet today — see
  `HOMELAB.md`'s Tailscale/ufw-bypass note). Gate is Forgejo's own
  per-user SSH key auth, not ufw.
  Clone example: `git clone ssh://git@100.78.110.5:2222/<user>/<repo>.git`

## Setup

```bash
mkdir -p ~/services/state/forgejo/data
docker compose -f ~/code/homelab/services/forgejo/docker-compose.yml up -d
```

First visit to `http://localhost:3000` (or via an SSH tunnel from
another machine: `ssh -L 3000:localhost:3000 am@100.78.110.5`) runs the
install wizard — defaults to SQLite (fine for this scale), the
`DOMAIN`/`ROOT_URL`/`SSH_DOMAIN`/`SSH_PORT` fields are already
pre-filled from the compose file's environment. Create the admin
account there. `DISABLE_REGISTRATION=true` is already set, so no one
else can self-register afterward — new users are admin-created only.

## Data / backup

`~/services/state/forgejo/data/` — everything (SQLite DB, repos, SSH
host keys, avatars, config). Back up by copying this directory
(stop the container first for a consistent SQLite snapshot).

## Ports

`3000` (web UI, localhost-only), `2222` (git-over-SSH, Tailscale-IP-only).
