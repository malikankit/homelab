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

## Steps

1. **Confirm current Tailscale state.** `tailscale status` — confirm
   the device shows as `mba13-mac` (already renamed per the 2026-08-22
   migration — see `../HOMELAB.md` changelog) and note its AM-tailnet IP
   for the machines table in `../HOMELAB.md`.

2. **Dedicated inter-host SSH key.** Follow the "one key per trust
   boundary" convention (`../HOMELAB.md` SSH key inventory): generate a
   `mba13-mac_to_tailnet_ed25519` keypair (mirror
   `generate_inter_host_key.sh`, adapted for macOS — no `chmod`
   differences needed, `ssh-keygen` is the same). Never reuse mbp16's or
   mba13-linux's keys. Copy the `.pub` into this repo folder (`mba13/`)
   for easy copy-paste into other machines' `authorized_keys`, same as
   the other machines' `.pub` files.

3. **Key-only SSH.** Enable Remote Login (System Settings → General →
   Sharing → Remote Login, or `sudo systemsetup -setremotelogin on`),
   add the relevant peer public keys to `~/.ssh/authorized_keys`, then
   harden `sshd_config` (or a drop-in under `/etc/ssh/sshd_config.d/` if
   the installed OpenSSH version supports it) to key-only auth —
   `PubkeyAuthentication yes`, `PasswordAuthentication no`,
   `KbdInteractiveAuthentication no`, `PermitRootLogin no` — matching
   `geekom/tailscale_setup.md` section (d). Verify with
   `sudo sshd -t` before restarting.

4. **Firewall: per-machine IP allowlist, not tailnet-wide.** macOS
   doesn't have `ufw` — use the Application Firewall
   (`/usr/libexec/ApplicationFirewall/socketfilterfw`) and/or `pf`
   (`/etc/pf.conf` + an anchor) to scope inbound SSH to only the known
   AM-tailnet peer IPs (mba13-linux, geekom-linux, mbp16-mac), same
   policy as `geekom/ufw_rules.sh` / `mba13/ufw_rules.sh` — not "any
   device on the tailnet." Write this as a script
   (`mba13/pf_rules_mac.sh` or similar) mirroring the existing
   `ufw_rules.sh` idempotent/re-runnable pattern, rather than one-off
   manual `pf` edits.

5. **Confirm Tailscale SSH is off.** `tailscale debug prefs` should show
   `"RunSSH": false` — same rationale as the other machines
   (`geekom/tailscale_setup.md` "Why not Tailscale SSH?").

6. **Update the allowlists on the other machines.** Once `mba13-mac`'s
   IP is known, add it to `geekom/ufw_rules.sh` and
   `mba13/ufw_rules.sh` (the Asahi side) — new machine → new IP added to
   every existing machine it needs to reach, per the pattern in
   `../HOMELAB.md`.

7. **Test.** Adapt `geekom/test_ssh_setup.sh` (key auth succeeds,
   password/keyboard-interactive rejected, LAN path unreachable) run
   from a peer machine against `mba13-mac`.

8. **Update `../HOMELAB.md`.** Fill in `mba13-mac`'s real IP in the
   Machines table (replacing the "not yet onboarded" placeholder), add
   its row to the SSH access map, SSH key inventory, and per-machine
   hardening status tables — same shape as the other three machines.

9. **Remove this file's TODO entry** from `../TODO.md` once done, and
   fold a short summary into `../HOMELAB.md`'s changelog.
