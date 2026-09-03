---
title: "geekom: decide on LUKS remote-unlock strategy"
status: open
created: 2026-09-03
updated: 2026-09-03
tags: [geekom, luks, security, always-on]
---

Root disk is LUKS-encrypted — on any reboot (crash, power blip, update),
geekom has no network stack until someone physically types the
passphrase, which defeats "always reachable via Tailscale" and already
caused an extended outage once (see the 2026-Aug-23 power-loss incident
in `geekom/early_journal.md`).

Options laid out in `geekom/always_on_setup.md` (Layer 3): TPM2
auto-unlock (convenient, trades away at-rest protection against physical
theft-while-off), `dropbear-initramfs` (needs a LAN-local relay device
to be useful from outside the LAN — more infra), or accept the risk
as-is. Needs a deliberate decision, not a default.
