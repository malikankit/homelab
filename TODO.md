# Homelab TODO

**Open work items now live as individual files in `issues/`** (see
`issues/README.md` for the convention) — this file is kept only as a
historical record of completed items.

## Completed

- [x] **Review the OneDrive → geekom rclone download for completeness.**
  Done — completed successfully: 373.446 GiB / 373.446 GiB (100%),
  353,622 / 353,622 files transferred per the run's own log
  (`geekom/logs/rclone-download-onedrive.log`), confirmed against disk
  (`du -sh` → 375G, `find | wc -l` → 353622 files — matches). A few
  transient errors mid-run (malformed drive id, one chunk timeout, one
  JWT parse error) self-resolved on retry.
- [x] **Create the Obsidian vault repo + a wiki repo on Forgejo.**
  Done — `obs` (vault) and `llmwiki` (LLM-generated wiki, pipeline
  TBD), both private, both empty. See `obsidian_sync_setup.md`.
- [x] **Configure `obsidian-git` on desktop(s)**, using Forgejo's
  per-user SSH key auth over `100.78.110.5:2222`. Done on both
  mba13-mac and mbp16-mac, each with its own dedicated key. See
  `obsidian_sync_setup.md` for the full runbook.
- [x] **Test the sync loop end-to-end**: edit a note → auto-commit →
  push → pull on a second device. Confirmed working.
- [x] **Push this `homelab` repo to Forgejo too**, not just GitHub.
  Done — `origin` has a second push URL (Forgejo, via a dedicated
  `geekom-linux_to_forgejo_ed25519` key), so a plain `git push` mirrors
  to both automatically. See `HOMELAB.md`.
- [x] **Onboard `mba13-mac` (outbound-only).** Done — zsh setup,
  dedicated outbound key (`mba13/mba13-mac_to_tailnet.pub`), SSH to
  geekom-linux confirmed working, inbound confirmed blocked (peer
  ssh/`nc` attempts fail, `tailscale debug prefs` shows `"RunSSH":
  false`), and `HOMELAB.md`'s machines/hardening tables filled in with
  its real IP (`100.71.170.17`). See `mba13/todo_mba13-mac_onboard.md`.
- [x] **geekom: set correct suspend/sleep settings for a home server.**
  Done — `geekom/disable_sleep.sh` masks the systemd sleep targets, sets
  an explicit `logind.conf` override, and locks the GNOME dconf settings.
  See `geekom/always_on_setup.md`.
- [x] **Migrate Claude Code sessions and projects from mba13-linux to geekom.**
  Done via `mba13/migrate_project.sh` for 8 projects (ailearning2026,
  crypto_prices_taxes, eth-portfolio-dashboard, snapshot-tool,
  full-offline-backup-for-todoist, lecce-libre, ledger-experiment,
  multibit2026) — see `mba13/logs/migrations/`. Two failed and need
  follow-up — see `issues/clean-migration-shprod-hedgit-archived.md`.
