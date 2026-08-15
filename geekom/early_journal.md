

## 2026-Aug-14

1. Setup SSH Key

ssh-keygen -t ed25519 -C "github@ankitmalik.in"

2. Install Clipboard and copy this file to clipboard

sudo apt install wl-clipboard

cat ~/.ssh/id_ed25519.pub | wl-copy
 

3. Git Clone homelab

cd ~/code/
git clone git@github.com:malikankit/homelab.git


4. Tailscale setup — Tailnet-only, key-only SSH (no Tailscale SSH, no passwords)

See tailscale_setup.md for full steps + rationale.


## Before 2026-Aug-14








