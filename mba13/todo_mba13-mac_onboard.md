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

3. **Confirm inbound is actually blocked.** — **done**: `ssh`/`nc`
   attempts from a peer both fail.

4. **Confirm Tailscale SSH is off.** — **done**: `tailscale debug prefs`
   shows `"RunSSH": false`.

5. **Update `../HOMELAB.md`.** — **done**: real IP (`100.71.170.17`)
   filled into the Machines table, hardening status table updated to
   "confirmed off" for both remaining columns.

6. **Remove this file's TODO entry** — **done**, `../TODO.md` now shows
   this onboarding as complete; see `../HOMELAB.md`'s changelog for the
   summary.

**Onboarding complete as of 2026-08-30.**
