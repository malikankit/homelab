# Homelab TODO

## High priority

- [ ] **Review the OneDrive → geekom rclone download for completeness.**
  Copied `rclone.conf` from mbp16-mac (its `OneDrive` remote,
  already-authenticated) to geekom's `~/.config/rclone/rclone.conf`, in
  progress: `rclone copy "OneDrive:Arq Backup Data/93F1AF98-1DA2-4FC6-8AA1-F32F1515AAA9"
  ~/onedrive_downloads/93F1AF98-1DA2-4FC6-8AA1-F32F1515AAA9 --progress`,
  running in the user's own tmux session. Check it actually completed
  (file count/size sanity check against OneDrive) once done.
- [x] **Create the Obsidian vault repo + a wiki repo on Forgejo.**
  Done — `obs` (vault) and `llmwiki` (LLM-generated wiki, pipeline
  TBD), both private, both empty. See `obsidian_sync_setup.md`.
- [x] **Configure `obsidian-git` on desktop(s)**, using Forgejo's
  per-user SSH key auth over `100.78.110.5:2222`. Done on both
  mba13-mac and mbp16-mac, each with its own dedicated key. See
  `obsidian_sync_setup.md` for the full runbook.
- [ ] **Test the sync loop end-to-end**: edit a note → auto-commit →
  push → pull on a second device. Not yet separately confirmed.
- [ ] **Set up LiveSync + CouchDB for Obsidian, alongside `obsidian-git`.**
  Per `gitandansiblesetupplan.md`'s Phase 2 options table: `obsidian-git`
  gives full Git history but only scheduled (not real-time) sync, with
  partial mobile support (Android via isomorphic-git; iOS more
  limited). LiveSync adds real-time sync + full mobile support but no
  version history on its own — the two don't conflict, so this layers
  LiveSync on top of the existing `obs`/`llmwiki` repos rather than
  replacing `obsidian-git`. Needs: CouchDB deployed on geekom (new
  `services/couchdb/`, same outside-repo state convention as the
  others), exposed only over Tailscale (same pattern as Forgejo — no
  raw port on a real interface), and the LiveSync community plugin
  configured on each device.
- [x] **Push this `homelab` repo to Forgejo too**, not just GitHub.
  Done — `origin` has a second push URL (Forgejo, via a dedicated
  `geekom-linux_to_forgejo_ed25519` key), so a plain `git push` mirrors
  to both automatically. See `HOMELAB.md`.
- [ ] **geekom: decide on LUKS remote-unlock strategy.** Root disk is
  LUKS-encrypted — geekom has no network stack after any reboot until
  someone physically types the passphrase, which already caused an
  extended outage once (see the 2026-Aug-23 power-loss incident in
  `geekom/early_journal.md`). See "Open" below for detail.
- [ ] **geekom: check BIOS "restore power after AC loss" setting.**
  Same incident — confirm geekom actually auto-boots after a real power
  outage. See "Open" below for detail.
- [ ] **Decide how to fix the Tailscale/ufw bypass.** Real reachability
  today is governed by Tailscale ACLs + sshd auth, not the per-machine
  ufw allowlists this repo otherwise documents as the security
  boundary — a live gap between documented and actual posture. See
  "Open" below for detail.

## Open

- [ ] **Add a `scpme` alias, same idea as `sshme`.** Per-machine,
  host-less — `scp -i <that machine's own tailnet identity key>` — so
  you append source/target yourself, same as `sshme`. Add to
  `dot_zshrc.tmpl`'s per-machine branches alongside the existing
  `sshme` entries.

- [ ] **Extend chezmoi tracking of `authorized_keys` to mba13-linux and
  mbp16-mac.** Only geekom's `~/.ssh/authorized_keys` is chezmoi-managed
  so far (`chezmoi/private_dot_ssh/private_authorized_keys`). The other
  two hosts' files weren't accessible to add from geekom directly —
  needs running `chezmoi add ~/.ssh/authorized_keys` on mba13-linux and
  mbp16-mac themselves (after `chezmoi.toml` is pointed at this repo's
  `chezmoi/` there), or pasting their current contents in so they can be
  added remotely. Since content differs per host, this can't just reuse
  geekom's file as-is — either keep per-host source files (e.g.
  `machine`-suffixed) or a `.tmpl` branching like `dot_zshrc.tmpl` does.
  See `chezmoi/README.md`'s "What's tracked here vs. not".

- [ ] **tmux: make Caps Lock act as a second prefix key alongside Ctrl+b.**
  On the Macs, Karabiner Elements now remaps Caps Lock to a held
  ⌘⌃⌥⇧ modifier chord (no keycode of its own — it only does anything
  combined with another key). Want e.g. Caps Lock+`:` to open tmux's
  command prompt the same way Ctrl+b then `:` does today, without
  breaking Ctrl+b. Complication: since Caps Lock alone sends no
  keystroke, "Caps Lock + key" arrives at tmux as a single chorded key
  event (e.g. Cmd-Ctrl-Opt-Shift-`:`), not two sequential events the
  way Ctrl+b then `:` does — so this likely can't be a generic
  `prefix2`, and instead needs individual `bind -n <chord+key>` entries
  in tmux.conf (which doesn't exist yet in this repo — would need to be
  added, likely under chezmoi) for each prefix command actually used,
  each mapped to what `prefix + <key>` currently does. Also need to
  confirm whether the terminal app (iTerm2 on both Macs, presumably)
  actually forwards Cmd-modified key combos to the shell at all, since
  terminals normally reserve Cmd for their own menu shortcuts. Needs
  the user's Karabiner config / terminal key-passthrough settings
  before this can be implemented correctly.

- [ ] **Decide how to fix the Tailscale/ufw bypass.** `tailscaled`
  inserts its own `ts-input` chain ahead of ufw's, so ufw's per-machine
  IP allowlist never runs for traffic arriving over Tailscale —
  confirmed empirically (SSH from mba13-mac succeeded despite its IP
  not being in geekom's allowlist). Real reachability today is
  Tailscale ACL policy (default allow-all) + sshd key-only auth, not
  ufw. Two fix directions, not yet chosen: write actual restrictive
  Tailscale ACLs in the admin console, or disable Tailscale's netfilter
  management (`--netfilter-mode=off`) so ufw can see/filter
  `tailscale0` traffic again. See `knowledge/tailscale_ufw_bypass.md`.

- [ ] **Re-run `ufw_rules.sh` on geekom-linux and mba13-linux after the
  hostname rename (2026-08-22).** The scripts' comments/variable names
  were updated in the repo to the new Tailnet names
  (`am6`→`geekom-linux`, `am-ma`→`mba13-linux`, `ams-mbp16`→`mbp16-mac`),
  but the *live* ufw rules on each machine still carry the old comment
  text (IPs are unchanged, so connectivity isn't affected — this is
  cosmetic only). Run `sudo ./ufw_rules.sh` on `geekom-linux` and on
  `mba13-linux` to bring the live comments in sync. See `HOMELAB.md`
  changelog for the full list of what else was renamed in this pass.

- [ ] **Onboard `mba13-mac` (outbound-only) — nearly done.** Scope
  narrowed: mba13-mac should never be SSH'd *into*, only used to SSH
  *out*. Inbound is already blocked via Tailscale's own "Disable
  incoming connections" toggle, so no macOS firewall/sshd hardening is
  needed. Done: zsh setup, dedicated outbound key
  (`mba13/mba13-mac_to_tailnet.pub`), SSH to geekom-linux confirmed
  working. Remaining: confirm inbound is actually blocked (ssh/nc
  attempt from a peer should fail), confirm `tailscale debug prefs`
  shows `"RunSSH": false`, fill in `HOMELAB.md`'s machines/hardening
  tables with mba13-mac's real IP. See
  `mba13/todo_mba13-mac_onboard.md`.

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
