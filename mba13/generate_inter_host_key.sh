#!/usr/bin/env bash
# Generate mba13-linux's dedicated inter-host SSH key — used for mba13-linux -> other
# AM-tailnet hosts (geekom-linux, mbp16-mac), never for GitHub or Zenith. See
# ../HOMELAB.md (SSH key inventory) for the "one key per trust boundary"
# convention this follows.
#
# Run this ON mba13-linux. It only touches ~/.ssh — no sudo needed.
# Idempotent: if the key already exists, it prints the existing pubkey
# instead of overwriting it.
#
# Usage: ./generate_inter_host_key.sh

set -euo pipefail

KEY="$HOME/.ssh/mba13-linux_to_tailnet_ed25519"
COMMENT="mba13-linux-tailnet@ankitmalik.in"

if [[ -f "$KEY" ]]; then
  echo "Key already exists at $KEY — not overwriting."
else
  mkdir -p "$HOME/.ssh"
  chmod 700 "$HOME/.ssh"
  ssh-keygen -t ed25519 -C "$COMMENT" -f "$KEY" -N ""
  echo "Generated $KEY"
fi

echo
echo "== Public key (copy this into the target host's authorized_keys," \
     "and paste it back so it can be added to homelab/mba13/) =="
cat "${KEY}.pub"
