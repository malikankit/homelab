# Instructions for Claude working in this repo

- **Keep `geekom/service_map.html` current.** It's a living diagram of
  the Docker services running on geekom and how each is reached
  (tailscale serve, Caddy, direct ports). Whenever a service is added,
  removed, or its exposure changes (new port, new proxy hop, etc.),
  update this diagram in the same batch of work — don't treat it as a
  one-time snapshot. **Keep this local-only — do not publish it (or any
  other diagram/doc from this repo) as a Claude Artifact.** View it by
  opening the file directly.
