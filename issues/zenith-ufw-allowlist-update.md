---
title: "Zenith network: update ufw allowlists with Zenith IPs"
status: open
created: 2026-09-03
updated: 2026-09-03
tags: [ufw, tailscale, zenith]
---

When any of these machines is next connected to the Zenith Tailscale
network (not just AM), get each machine's Zenith-network IP (`tailscale
status` while on Zenith) and add it to the relevant `ufw_rules.sh`
scripts — same pattern already used for `mbp16-mac`'s Zenith IP
(`100.108.204.52`) in `mba13/ufw_rules.sh`. Then **re-run
`sudo ./ufw_rules.sh` on the affected machine(s)** to actually apply it —
editing the script alone doesn't change the live firewall.

See `HOMELAB.md` (Tailscale networks / trust model) and
`knowledge/tailscale_udp_41641.md` for context on why Zenith is treated
as lower-trust than AM.
