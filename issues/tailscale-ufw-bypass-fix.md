---
title: "Decide how to fix the Tailscale/ufw bypass"
status: open
created: 2026-09-03
updated: 2026-09-03
tags: [tailscale, ufw, security, geekom]
---

`tailscaled` inserts its own `ts-input` chain ahead of ufw's, so ufw's
per-machine IP allowlist never runs for traffic arriving over Tailscale
— confirmed empirically (SSH from mba13-mac succeeded despite its IP not
being in geekom's allowlist). Real reachability today is Tailscale ACL
policy (default allow-all) + sshd key-only auth, not ufw — a live gap
between documented and actual posture.

Two fix directions, not yet chosen: write actual restrictive Tailscale
ACLs in the admin console, or disable Tailscale's netfilter management
(`--netfilter-mode=off`) so ufw can see/filter `tailscale0` traffic
again. See `knowledge/tailscale_ufw_bypass.md`.
