# chezmoi — managed dotfiles

Real dotfiles (`.zshrc`, `.p10k.zsh`, `.gitconfig`, …), managed by
[chezmoi](https://www.chezmoi.io/), tracked here as this homelab repo's
source of truth. This is **not** a plain backup copy — the files here
and the live files in `~/` are kept in sync explicitly through
`chezmoi diff`/`chezmoi apply`, which removes the manual-copy drift
problem an earlier plain-backup approach had.

chezmoi's source directory is this folder, *inside* the homelab repo
(not a separate dedicated dotfiles repo) — chezmoi just shells out to
`git`, which auto-detects the parent repo, so `chezmoi git ...` and
plain `git` commands both work fine run from here.

## File naming

chezmoi source files drop the leading `.` and prefix it with `dot_`
(e.g. `.zshrc` → `dot_zshrc`) so they aren't hidden files inside the
repo itself. See chezmoi's
[source state docs](https://www.chezmoi.io/reference/source-state-attributes/)
for the rest of its naming conventions if you add templated or
per-machine-conditional files later.

## Bootstrapping a new machine

```bash
# 1. Clone/pull this repo to ~/code/homelab first (existing convention).

# 2. Install chezmoi (no sudo needed, installs to ~/.local/bin):
sh -c "$(curl -fsSL https://get.chezmoi.io)" -- -b ~/.local/bin

# 3. Point chezmoi at this repo's chezmoi/ folder as its source:
mkdir -p ~/.config/chezmoi
echo 'sourceDir = "'"$HOME"'/code/homelab/chezmoi"' > ~/.config/chezmoi/chezmoi.toml

# 4. Apply — writes .zshrc/.p10k.zsh/.gitconfig into ~/:
~/.local/bin/chezmoi apply
```

`~/.config/chezmoi/chezmoi.toml` itself is not tracked here — it's the
one small bootstrap step every machine needs before chezmoi knows
where to find its source directory.

## Day-to-day workflow

- **Edit a managed file**: edit the source file here directly (e.g.
  `dot_zshrc`), or `chezmoi edit ~/.zshrc` (opens the source file for
  you). Then:
  ```bash
  chezmoi diff     # preview what would change on disk
  chezmoi apply    # write the change into ~/
  ```
- **Someone/something changed the live file directly** (e.g. you
  edited `~/.zshrc` by hand): `chezmoi diff` shows the live file
  differs from source — resolve by either `chezmoi apply` (source
  wins, overwrites the live edit) or `chezmoi add ~/.zshrc` (live file
  wins, updates the source to match), then commit.
- **Add a new file to management**: `chezmoi add ~/.some_dotfile`.
- **Commit changes**: plain `git add`/`git commit` from anywhere in
  the homelab repo, same as everything else in it.

## What's tracked here vs. not

Tracked: `.zshrc`, `.p10k.zsh`, `.gitconfig` — config with no secrets
in it. **Not** tracked, and shouldn't be added: `.ssh/`, `.gnupg/`,
anything under `.config/` with API keys/tokens, shell history files,
caches (`.zcompdump*`, `.cache/`), or other app-generated state. If in
doubt before `chezmoi add`-ing something, check it for embedded
secrets first.
