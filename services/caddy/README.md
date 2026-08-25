# Caddy

Reverse proxy sitting between `tailscale serve` and Forgejo. Only reason
it's here rather than pointing `tailscale serve` straight at Forgejo's
port: this is the intended place to add path-based routing once more
services join the tailnet-exposed side of this stack (per
`gitandansiblesetupplan.md`'s Phase 2) — for now it's a thin pass-through
to `../forgejo`.

## How it's wired

- Runs with `network_mode: host` so its Caddyfile can reach Forgejo at
  `127.0.0.1:3000` directly, no shared docker network needed.
- Caddyfile binds explicitly to `127.0.0.1:8080` — despite host
  networking, this keeps it unreachable from the LAN; only
  `tailscale serve` (running on the host, also loopback-only by
  default) fronts it.
- `tailscale serve https / http://127.0.0.1:8080` terminates TLS using
  this tailnet's HTTPS Certificates feature
  (`6l.seahorse-enigmatic.ts.net`) and forwards to Caddy, which forwards
  to Forgejo. No port is opened on any real network interface at any
  layer — `tailscale serve` handles routing entirely within
  `tailscaled`.

## Setup

```bash
mkdir -p ~/services/state/caddy/{data,config}
docker compose -f ~/code/homelab/services/caddy/docker-compose.yml up -d

# One-time, needs sudo:
sudo tailscale serve https / http://127.0.0.1:8080
```

Verify from another tailnet device (not geekom itself):
`https://6l.seahorse-enigmatic.ts.net/` should load Forgejo's UI with a
valid cert (no browser warning).

## Data

`~/services/state/caddy/{data,config}/` — Caddy's own state (TLS
internal storage, autosave config). Caddy issues no certs of its own
here (TLS is handled by `tailscale serve`), so this is mostly empty;
kept for parity with the rest of this repo's state-outside-git
convention.

## Port

`8080`, localhost-only (`tailscale serve` is the only thing that should
ever reach it).
