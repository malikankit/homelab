#!/usr/bin/env bash
# ufw firewall rules for geekom-linux (geekom) — Tailnet + per-machine allowlist.
#
# Policy (see ../HOMELAB.md): SSH is reachable only from specific known
# AM-tailnet peers by IP — not "any device on the tailnet". Tailnet
# membership/ACLs (especially on Zenith, which has other admins/users)
# aren't trusted as the perimeter; this allowlist is the actual boundary.
# Matches the stricter model already in use on mba13-linux.
#
# This is the living source of truth for firewall rules. As new machines
# or services need access, add a rule here rather than running one-off
# `ufw` commands.
#
# Idempotent: safe to re-run any time (e.g. after editing) to reapply.
# Rules from a previous version of this script that are no longer listed
# below are explicitly deleted (see CURRENT_SSH_RULES / retire step).
#
# Usage: sudo ./ufw_rules.sh

set -euo pipefail

# --- Known AM-tailnet peers allowed to SSH into geekom-linux ---
MBA13_LINUX_IP="100.105.210.109"      # mba13-linux (mba13, Asahi Linux)
MBP16_MAC_IP="100.87.74.44"     # mbp16-mac (mbp16), AM tailnet

# --- Tailscale's own port: needed for direct (non-relayed) connections ---
# See ../knowledge/tailscale_udp_41641.md for why this is open to
# "Anywhere" rather than tailscale0-scoped, and why it's unrelated to
# tailnet switching.
ufw allow 41641/udp comment 'Tailscale'

# --- Retire the old tailnet-wide rule from the first version of this script ---
ufw delete allow in on tailscale0 to any port 22 proto tcp 2>/dev/null || true

# --- SSH: only from known peers, arriving via the tailscale0 interface ---
ufw allow in on tailscale0 from "$MBA13_LINUX_IP" to any port 22 proto tcp comment 'SSH from mba13-linux'
ufw allow in on tailscale0 from "$MBP16_MAC_IP" to any port 22 proto tcp comment 'SSH from mbp16-mac'

# --- Add future per-machine / per-service rules above this line, e.g.: ---
# ufw allow in on tailscale0 from <IP> to any port <PORT> proto tcp comment '<what> from <machine>'

# --- Defaults: deny all other inbound, allow all outbound ---
ufw default deny incoming
ufw default allow outgoing

# --force skips the interactive "disrupt existing ssh connections?" prompt
ufw --force enable

ufw status verbose
