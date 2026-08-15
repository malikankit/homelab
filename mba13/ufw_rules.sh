#!/usr/bin/env bash
# ufw firewall rules for am-ma (mba13, Asahi Linux) — Tailnet +
# per-machine allowlist.
#
# Policy (see ../HOMELAB.md): SSH is reachable only from specific known
# AM-tailnet peers by IP — not "any device on the tailnet". Tailnet
# membership/ACLs (especially on Zenith, which has other admins/users)
# aren't trusted as the perimeter; this allowlist is the actual boundary.
#
# This reflects the rules already live on am-ma (captured in
# ufw_status.md) plus am6 (geekom), which was pending. The 41641/udp rule
# is Tailscale's own port — see ../knowledge/tailscale_udp_41641.md for
# why it's left open to "Anywhere" rather than tailscale0-scoped, and why
# it's unrelated to tailnet switching (AM <-> Zenith).
#
# This is the living source of truth for firewall rules. As new machines
# or services need access, add a rule here rather than running one-off
# `ufw` commands.
#
# Idempotent: safe to re-run any time (e.g. after editing) to reapply.
#
# Usage: sudo ./ufw_rules.sh

set -euo pipefail

# --- Known AM-tailnet peers allowed to SSH into am-ma ---
AM6_IP="100.78.110.5"                # am6 (geekom)
AMS_MBP16_AM_IP="100.87.74.44"       # ams-mbp16 (mbp16), AM tailnet
AMS_MBP16_ZENITH_IP="100.108.204.52" # ams-mbp16 (mbp16), Zenith tailnet

# --- Tailscale's own port: needed for direct (non-relayed) connections ---
ufw allow 41641/udp comment 'Tailscale'

# --- Retire the old rules (no interface scoping) from before this script existed ---
ufw delete allow from "$AMS_MBP16_AM_IP" to any port 22 2>/dev/null || true
ufw delete allow from "$AMS_MBP16_ZENITH_IP" to any port 22 2>/dev/null || true

# --- SSH: only from known peers, arriving via the tailscale0 interface ---
ufw allow in on tailscale0 from "$AM6_IP" to any port 22 proto tcp comment 'SSH from am6'
ufw allow in on tailscale0 from "$AMS_MBP16_AM_IP" to any port 22 proto tcp comment 'SSH from ams-mbp16 (AM tailnet)'
ufw allow in on tailscale0 from "$AMS_MBP16_ZENITH_IP" to any port 22 proto tcp comment 'SSH from ams-mbp16 (Zenith tailnet)'

# --- Add future per-machine / per-service rules above this line, e.g.: ---
# ufw allow in on tailscale0 from <IP> to any port <PORT> proto tcp comment '<what> from <machine>'

# --- Defaults: deny all other inbound, allow all outbound ---
ufw default deny incoming
ufw default allow outgoing

# --force skips the interactive "disrupt existing ssh connections?" prompt
ufw --force enable

ufw status verbose
