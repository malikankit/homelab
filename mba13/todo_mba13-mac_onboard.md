# Onboard mba13-mac

Meant to be invoked from Claude Code **running on the macOS boot of
mba13 itself** (not from geekom-linux or mba13-linux) — clone/pull this
repo there first, then point Claude at this file.

## Context

`mba13` physically dual-boots macOS and Asahi Linux. The Asahi side is
already fully onboarded into this homelab as `mba13-linux` (see
`../HOMELAB.md`, `ufw_rules.sh`, `generate_inter_host_key.sh`). The
macOS side is a **separate OS install with its own filesystem, SSH
daemon, and firewall** — nothing about `mba13-linux`'s hardening carries
over automatically, even though it's the same physical hardware and
already sits on the AM Tailscale network today.

Treat this the same way `mbp16` (macOS) was onboarded — `geekom/` and
`mba13/` are the reference pattern, but macOS needs different tooling
(Application Firewall / `pf` instead of `ufw`, `launchd` instead of
`systemd`).

**Scope note (2026-08-22):** mba13-mac is **outbound-only** — it should
never be SSH'd *into*, only used to SSH *out* to other AM-tailnet hosts.
Confirmed via Tailscale's own "Disable incoming connections" toggle
(macOS app), which blocks all inbound tailnet traffic to this device at
the Tailscale layer itself. This removes the need for inbound-facing
hardening (macOS Application Firewall/`pf` allowlist, sshd key-only
config, Remote Login enabled, other machines' ufw allowlists) — those
steps only mattered if something needed to reach *in*. Steps below are
trimmed to reflect that; see `../TODO.md` for the current status.

## Steps

1. **Confirm current Tailscale state.** `tailscale status` — confirm
   the device shows as `mba13-mac` (already renamed per the 2026-08-22
   migration — see `../HOMELAB.md` changelog) and note its AM-tailnet IP
   for the machines table in `../HOMELAB.md`. — **done**, zsh setup and
   outbound SSH to geekom-linux both confirmed working.

2. **Dedicated inter-host SSH key.** Follow the "one key per trust
   boundary" convention (`../HOMELAB.md` SSH key inventory): generate a
   `mba13-mac_to_tailnet` keypair (mirror `generate_inter_host_key.sh`,
   adapted for macOS — no `chmod` differences needed, `ssh-keygen` is
   the same). Never reuse mbp16's or mba13-linux's keys. Copy the `.pub`
   into this repo folder (`mba13/`) for easy copy-paste into other
   machines' `authorized_keys`, same as the other machines' `.pub`
   files. — **done**: `mba13/mba13-mac_to_tailnet.pub`, authorized on
   geekom-linux.

3. **Confirm inbound is actually blocked.** Since mba13-mac doesn't
   need to accept SSH, verify the negative instead of hardening for the
   positive: from another AM-tailnet peer, confirm
   `ssh <user>@<mba13-mac-ip>` and `nc -zv -w3 <mba13-mac-ip> 22` both
   fail/time out. (Belt-and-suspenders: Remote Login should also stay
   **off** in System Settings → General → Sharing — no sshd listening
   at all is stronger than sshd-listening-but-blocked-by-Tailscale.)

4. **Confirm Tailscale SSH is off.** `tailscale debug prefs` should show
   `"RunSSH": false` — same rationale as the other machines
   (`geekom/tailscale_setup.md` "Why not Tailscale SSH?"). Belt-and-
   suspenders alongside the "Disable incoming connections" toggle, not
   a substitute for it.

5. **Update `../HOMELAB.md`.** Fill in `mba13-mac`'s real IP in the
   Machines table (replacing the "not yet onboarded" placeholder), note
   it's outbound-only/inbound-blocked-via-Tailscale in the per-machine
   hardening status table, and add an outbound-only row to the SSH
   access map — same shape as the other three machines, adjusted for
   the outbound-only model.

6. **Remove this file's TODO entry** from `../TODO.md` once done, and
   fold a short summary into `../HOMELAB.md`'s changelog.
