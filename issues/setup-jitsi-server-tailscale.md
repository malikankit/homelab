---
title: "Set up a Jitsi Meet server, reachable only over Tailscale"
status: open
created: 2026-10-16
updated: 2026-10-16
tags: [services, jitsi, tailscale, planning-only]
---

## Context

Want self-hosted video calling on geekom, reachable only from the
AM-tailnet (same exposure model as every other service here — see
`../geekom/service_map.html`). Parked behind Vikunja for now — revisit
once that's running.

## Components

Jitsi Meet is four containers, not one: `web` (UI), `prosody` (XMPP
signaling), `jicofo` (conference focus/orchestration), `jvb` (video
bridge — actually relays media). Add as
`services/jitsi/docker-compose.yml`, matching the existing
`services/*/docker-compose.yml` convention, wired into Dockge like the
other stacks.

## Exposure strategy — the one real design decision

Two different parts, handled differently:

1. **Web UI (signaling, HTTP)** — same pattern as CryptPad: its own
   dedicated `tailscale serve` port, not routed through Caddy. Jitsi's
   web UI doesn't play well behind a path-based reverse proxy either.
2. **JVB (media, UDP 10000)** — genuinely different from every other
   service here. WebRTC media doesn't go through `tailscale serve` or
   Caddy at all — JVB advertises an IP:port that participants' browsers
   connect to directly. Set `JVB_ADVERTISE_IPS` to geekom's Tailscale IP
   (`100.78.110.5`) and run JVB with **host networking** (avoids
   Docker's NAT interfering with UDP reachability), bound only to that
   interface. No public internet exposure, no STUN/TURN needed — every
   peer is already on the tailnet.

## Other setup needed

- A domain Jitsi's web UI/certs can reference — geekom's Tailscale
  MagicDNS name (`6l.seahorse-enigmatic.ts.net`, same one Forgejo
  already uses) works here.
- Auth passwords for `jicofo`↔`prosody` (generate once, store in an env
  file — **not committed to git**).
- Resource footprint: modest when idle (~1-2GB RAM for all 4
  containers combined) — shouldn't conflict with the transcription
  pipeline's heavier spikes, but avoid starting calls while a
  transcription/diarization job is mid-run on this same 10GB box.

## What to update alongside building this

- `geekom/service_map.html` — new node, per `CLAUDE.md`'s rule to keep
  it current whenever a service's exposure changes.
- A short `services/jitsi/README.md` explaining the UDP/host-networking
  choice, matching `tools/hindi_translation/RUNBOOK.md`'s style of
  recording *why*, not just *what*.

## Open question for when this gets picked up

Keep the web UI on its own `tailscale serve` port (CryptPad pattern), or
route it through Caddy instead (Forgejo pattern)? Leaning toward its own
port, since Jitsi's web UI has its own assumptions about being the only
thing at its origin — not decided, revisit then.

## Not yet done

Nothing built. Parked behind Vikunja server setup.
