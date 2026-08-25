# Obsidian sync via Forgejo — client setup

How `obsidian-git` was wired up on both mba13-mac and mbp16-mac to sync
two Obsidian vaults through Forgejo (`services/forgejo/`) on geekom.
Phase 1 of `gitandansiblesetupplan.md`.

## The two vaults/repos

- **`obs`** — the actual, day-to-day Obsidian vault. Synced
  continuously via `obsidian-git` as notes are edited.
- **`llmwiki`** — a separate vault/repo for an LLM-generated wiki (the
  plan doc's "Karpathy-style automated wiki pipeline"). Kept as its own
  repo rather than mixed into `obs` since it has a different commit
  cadence and access pattern (batch/automated regeneration vs. manual
  edits) — the pipeline itself isn't built yet; this repo is just the
  destination for it.

Both created as **private**, **empty** (no README/.gitignore/license)
repos on Forgejo, under the admin account, via the web UI at
`https://6l.seahorse-enigmatic.ts.net/`.

## Per-machine SSH key convention

Each machine gets its **own dedicated key** for Forgejo access — not
reused from GitHub or the inter-host AM-tailnet keys — matching this
repo's existing "one key per trust boundary" convention (see
`HOMELAB.md`'s SSH key inventory). Generated with no passphrase, since
`obsidian-git` needs to push/pull unattended:

```bash
ssh-keygen -t ed25519 -C "<machine>_to_forgejo" -N "" -f ~/.ssh/<machine>_to_forgejo_ed25519
```

Run on both `mba13-mac` (`mba13-mac_to_forgejo_ed25519`) and `mbp16-mac`
(`mbp16-mac_to_forgejo_ed25519`). Public keys were added individually to
the same Forgejo user account under **Settings → SSH/GPG Keys**, one
entry per machine (titled `mba13-mac` / `mbp16-mac`) — private keys
never leave the machine they were generated on, and neither key is
tracked in this repo.

## SSH config alias

Added to `~/.ssh/config` on each machine, so plain `git` commands don't
need `-i`/port flags:

```
Host forgejo
    HostName 100.78.110.5
    Port 2222
    User git
    IdentityFile ~/.ssh/<machine>_to_forgejo_ed25519
    IdentitiesOnly yes
```

Same alias name (`forgejo`) on both machines, pointing at each
machine's own key — the alias itself isn't tracked here since it lives
in `~/.ssh/config`, outside chezmoi's scope (see `chezmoi/README.md`'s
"what's tracked here vs. not").

## Cloning and obsidian-git

```bash
git clone forgejo:<forgejo-username>/obs.git
git clone forgejo:<forgejo-username>/llmwiki.git
```

Then in Obsidian: **Settings → Community plugins → Browse → "Obsidian
Git" → Install → Enable**, pointed at each cloned folder as its vault,
with auto-commit/auto-pull interval configured per the user's
preference.

## Status

Executed on both mba13-mac and mbp16-mac. Sync-loop testing (edit on
one device → auto-commit → push → pull on the other) not yet
separately confirmed — see `TODO.md`.
