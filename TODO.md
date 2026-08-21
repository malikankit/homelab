# Homelab TODO

## Open

- [ ] **Re-run `ufw_rules.sh` on geekom-linux and mba13-linux after the
  hostname rename (2026-08-22).** The scripts' comments/variable names
  were updated in the repo to the new Tailnet names
  (`am6`→`geekom-linux`, `am-ma`→`mba13-linux`, `ams-mbp16`→`mbp16-mac`),
  but the *live* ufw rules on each machine still carry the old comment
  text (IPs are unchanged, so connectivity isn't affected — this is
  cosmetic only). Run `sudo ./ufw_rules.sh` on `geekom-linux` and on
  `mba13-linux` to bring the live comments in sync. See `HOMELAB.md`
  changelog for the full list of what else was renamed in this pass.

- [ ] **Onboard `mba13-mac` into this repo's hardening.** The macOS boot
  on mba13 is already on the AM Tailscale network but not yet
  key-only-SSH/ufw-hardened or documented here. See
  `mba13/todo_mba13-mac_onboard.md` — written to be run/invoked from
  Claude Code on that machine directly.

- [ ] **Zenith network: update ufw allowlists with Zenith IPs.** When any
  of these machines is next connected to the Zenith Tailscale network
  (not just AM), get each machine's Zenith-network IP (`tailscale status`
  while on Zenith) and add it to the relevant `ufw_rules.sh` scripts —
  same pattern already used for `mbp16-mac`'s Zenith IP
  (`100.108.204.52`) in `mba13/ufw_rules.sh`. Then **re-run
  `sudo ./ufw_rules.sh` on the affected machine(s)** to actually apply
  it — editing the script alone doesn't change the live firewall.
  See `HOMELAB.md` (Tailscale networks / trust model) and
  `knowledge/tailscale_udp_41641.md` for context on why Zenith is treated
  as lower-trust than AM.

- [ ] **DNS status: investigate Tailscale health warning on mba13-linux.**
  `tailscale status` on mba13-linux reports: `Tailscale can't reach the
  configured DNS servers. Internet connectivity may be affected.` Root
  cause unknown yet — check `resolvectl status`, what DNS servers
  Tailscale/MagicDNS is configured to use (admin console DNS settings vs.
  what's actually reachable from mba13-linux), and whether this is related to
  or separate from the MagicDNS short-hostname resolution issue seen on
  geekom (short name `mba13-linux` didn't resolve there, but the Tailscale IP
  worked fine).

- [ ] **mba13: formalize sshd hardening as a script.** mba13-linux already has
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

- [x] **Migrate Claude Code sessions and projects from mba13-linux to geekom.**
  Done via `mba13/migrate_project.sh` for 8 projects (ailearning2026,
  crypto_prices_taxes, eth-portfolio-dashboard, snapshot-tool,
  full-offline-backup-for-todoist, lecce-libre, ledger-experiment,
  multibit2026) — see `mba13/logs/migrations/`. Two failed and need
  follow-up (below).

- [ ] **Clean migration for `shprod` and `hedgit_archived`.** Both failed
  via `migrate_project.sh` on 2026-08-16, leaving partial/incomplete
  directories on geekom-linux (rsync errored partway through). Those
  partial copies have been deleted from geekom-linux — originals on
  mba13-linux are untouched (cleanup was never offered for failed runs).
  `shprod` has noticeably tighter permissions (`750`) than the other
  projects (`775`), possibly a read-permission issue on some file — worth
  capturing the actual rsync error text (the migration log only records
  pass/fail) before retrying.
