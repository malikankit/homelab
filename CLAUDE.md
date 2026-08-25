# Instructions for Claude working in this repo

- **Keep `geekom/service_map.html` current.** It's a living diagram of
  the Docker services running on geekom and how each is reached
  (tailscale serve, Caddy, direct ports). Whenever a service is added,
  removed, or its exposure changes (new port, new proxy hop, etc.),
  update this diagram in the same batch of work — don't treat it as a
  one-time snapshot. It's also published as a Claude Artifact; if
  regenerated there, copy the resulting HTML back over this file so the
  repo copy doesn't drift from what's actually being shown.
