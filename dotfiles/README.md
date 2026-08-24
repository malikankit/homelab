# dotfiles

Shared shell config, meant to be `source`d from every machine's own
`.bashrc`/`.zshrc` — one canonical copy, tracked and pushed like
everything else in this repo, instead of copy-pasted per machine.

## Files

- `aliases.sh` — aliases common to every machine. POSIX-safe on
  purpose, so the same file works whether it's sourced from bash or
  zsh. Machine-specific aliases (e.g. a host-specific SSH shortcut with
  a particular key path) are **not** here — they stay local, added
  directly in that machine's own rc file below the sourced block.

## How to wire it up

Add this near the top of `~/.zshrc` (or `~/.bashrc`), after `PATH` is
set up (aliases don't need `PATH`, but keeping shared config in one
predictable spot is easier to scan):

```sh
[ -f ~/code/homelab/dotfiles/aliases.sh ] && source ~/code/homelab/dotfiles/aliases.sh
```

This assumes the homelab repo is cloned at `~/code/homelab` on that
machine — the convention already used elsewhere in this repo (see
`hl`/`hlg` aliases in `aliases.sh` itself).

## Why aliases go in `.bashrc`/`.zshrc`, not `.bash_profile`/`.zprofile`

Aliases only need to exist in *interactive* shells (a human typing at a
prompt), and `.bashrc`/`.zshrc` are exactly the files sourced for every
new interactive shell — a new terminal tab, a new SSH session, `tmux
attach`, all of them. `.bash_profile`/`.zprofile`/`.profile` are
*login*-shell files: they only run once per login (e.g. the very first
shell after `ssh`ing in), not for every subsequent shell you open in
that session — so aliases placed there can appear to "randomly" not
exist depending on how a given shell was spawned. Put aliases (and
anything else interactive-only, like this) in the rc file, not the
profile file.

## Adding a new shared alias

Edit `aliases.sh` here, commit, then `git pull` (or however each
machine syncs this repo) on the other machines to pick it up — no
per-machine editing needed.
