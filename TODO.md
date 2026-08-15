# Homelab TODO

## Open

- [ ] **Zenith network: update ufw allowlists with Zenith IPs.** When any
  of these machines is next connected to the Zenith Tailscale network
  (not just AM), get each machine's Zenith-network IP (`tailscale status`
  while on Zenith) and add it to the relevant `ufw_rules.sh` scripts —
  same pattern already used for `ams-mbp16`'s Zenith IP
  (`100.108.204.52`) in `mba13/ufw_rules.sh`. Then **re-run
  `sudo ./ufw_rules.sh` on the affected machine(s)** to actually apply
  it — editing the script alone doesn't change the live firewall.
  See `HOMELAB.md` (Tailscale networks / trust model) and
  `knowledge/tailscale_udp_41641.md` for context on why Zenith is treated
  as lower-trust than AM.

- [ ] **DNS status: investigate Tailscale health warning on am-ma.**
  `tailscale status` on am-ma reports: `Tailscale can't reach the
  configured DNS servers. Internet connectivity may be affected.` Root
  cause unknown yet — check `resolvectl status`, what DNS servers
  Tailscale/MagicDNS is configured to use (admin console DNS settings vs.
  what's actually reachable from am-ma), and whether this is related to
  or separate from the MagicDNS short-hostname resolution issue seen on
  geekom (short name `am-ma` didn't resolve there, but the Tailscale IP
  worked fine).

- [ ] **mba13: formalize sshd hardening as a script.** am-ma already has
  key-only SSH working via a pre-existing drop-in
  (`/etc/ssh/sshd_config.d/10-key-only.conf`, dated Feb 9 2026, not
  tracked in this repo), but two settings don't match geekom's baseline:
  `AuthenticationMethods` is `any` (geekom: `publickey`, declared not
  just implicit) and `PermitRootLogin` is `prohibit-password` (geekom:
  `no`). Write `mba13/sshd_hardening.sh` mirroring
  `geekom/sshd_hardening.sh` (backup/apply/verify pattern) and align
  those two directives.

- [x] **geekom: set correct suspend/sleep settings for a home server.**
  Done — `geekom/disable_sleep.sh` masks the systemd sleep targets, sets
  an explicit `logind.conf` override, and locks the GNOME dconf settings.
  See `geekom/always_on_setup.md`.

- [ ] **geekom: decide on LUKS remote-unlock strategy.** Root disk is
  LUKS-encrypted — on any reboot (crash, power blip, update), geekom has
  no network stack until someone physically types the passphrase, which
  defeats "always reachable via Tailscale." Options laid out in
  `geekom/always_on_setup.md` (Layer 3): TPM2 auto-unlock (convenient,
  trades away at-rest protection against physical theft-while-off),
  `dropbear-initramfs` (needs a LAN-local relay device to be useful from
  outside the LAN — more infra), or accept the risk as-is. Needs a
  deliberate decision, not a default.

- [ ] **geekom: check BIOS "restore power after AC loss" setting.**
  Firmware-level, can't be checked/changed from software — confirm
  geekom auto-boots after a real power outage rather than staying off
  until a physical button press. See `geekom/always_on_setup.md`.

- [ ] **Migrate Claude Code sessions and projects from am-ma to geekom.**
  Pick which folders under am-ma's `~/code/` to migrate, then transfer
  both the project folder and its matching
  `~/.claude/projects/<mangled-path>/` directory to the identical
  absolute path on geekom, over the Tailscale SSH connection, so
  `/resume` finds the old sessions. See
  `knowledge/claude_code_session_migration.md` for the mechanics/caveats.
