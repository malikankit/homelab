# Dockge

Compose-native container management UI for geekom — no lock-in, stacks
are plain `docker-compose.yml` files.

The compose definition here is git-tracked (this repo); its runtime
state lives outside the repo, under `~/services/state/dockge/`, so
data/secrets never end up in git.

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
mkdir -p ~/services/state/dockge/{data,stacks}
docker compose -f ~/code/homelab/services/dockge/docker-compose.yml up -d
```

First visit to `http://localhost:5001` prompts you to create the admin
account.

## Managing other stacks in this repo through Dockge's UI

Dockge can see every running container regardless of how it was
started (it has Docker-socket access), but only offers full management
(start/stop/restart from its UI) for stacks whose compose file lives
under its own `DOCKGE_STACKS_DIR` (`~/services/state/dockge/stacks/` on
the host). To manage a repo-tracked stack (e.g. `../caddy`,
`../forgejo`) through Dockge without duplicating its compose file:

```bash
# One-time per stack, run as root inside the container (the host-side
# stacks dir is root-owned):
docker exec dockge ln -s /home/am/code/homelab/services/<name> /opt/stacks/<name>
```

This only resolves because the compose file also has to explicitly
mount `~/code/homelab/services` into the container (read-only) at the
identical absolute path — already set up in this stack's
`docker-compose.yml`. Read-only on purpose: compose-file edits should
still only happen via git, never Dockge's UI, so there's one source of
truth. Caddy and Forgejo are symlinked in this way as of 2026-08-25.

## Data / backup

- `~/services/state/dockge/data/` — Dockge's own app data (accounts,
  settings)
- `~/services/state/dockge/stacks/` — Dockge-native stacks live here as
  plain files; `caddy`/`forgejo` are symlinks back into the repo (see
  above), not copies — nothing to back up for those beyond the repo
  itself.

## Port

`5001` (UI), localhost-only per above.
