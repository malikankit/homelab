#!/usr/bin/env bash
# ufw firewall rules for this machine — Tailnet-only exposure.
#
# This is the living source of truth for firewall rules. As new services
# get installed, add a rule here (scoped to `tailscale0` unless there's a
# specific reason not to) rather than running one-off `ufw` commands.
#
# Idempotent: safe to re-run any time (e.g. after editing) to reapply.
#
# Usage: sudo ./ufw_rules.sh

set -euo pipefail

# --- SSH: Tailnet only, no LAN/public IPs ---
ufw allow in on tailscale0 to any port 22 proto tcp comment 'SSH via Tailnet only'

# --- Add future service rules above this line, e.g.: ---
# ufw allow in on tailscale0 to any port <PORT> proto tcp comment '<service> via Tailnet only'

# --- Defaults: deny all other inbound, allow all outbound ---
ufw default deny incoming
ufw default allow outgoing

# --force skips the interactive "disrupt existing ssh connections?" prompt
ufw --force enable

ufw status verbose
