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
repo itself. A `.tmpl` suffix (`dot_zshrc.tmpl`) marks a templated file —
see [source state docs](https://www.chezmoi.io/reference/source-state-attributes/)
for the rest of chezmoi's naming conventions.

`dot_zshrc.tmpl` is templated because `.zshrc` isn't identical across
machines — each has its own machine-specific aliases (e.g. `sham` on
geekom-linux, `sshg`/`sshl` on mba13-mac). The template branches on a
`machine` variable (see "Bootstrapping a new machine" below) rather than
chezmoi's own `.chezmoi.hostname`, so renaming a machine at the OS or
Tailscale level doesn't silently change which alias block it gets — that
only changes when `chezmoi.toml` is deliberately updated. See
`../HOMELAB.md` for the machine name ↔ Tailscale short-name mapping
(`geekom-linux`=`6l`, `mba13-linux`=`13l`, `mba13-mac`=`13m`,
`mbp16-mac`=`16m`).

## Bootstrapping a new machine

On mba13-mac/mbp16-mac, this is done automatically via `../basic_setup.sh`
at the repo root (a shared, section-by-section confirmed script — see
its own header comment) — it detects which of those two machines it's
running on and sets `machine` accordingly. geekom was bootstrapped by
hand, not via a script. To do it by hand, or on a new machine
`basic_setup.sh` doesn't yet recognize:

```bash
# 1. Clone/pull this repo to ~/code/homelab first (existing convention).

# 2. Install chezmoi (no sudo needed, installs to ~/.local/bin):
sh -c "$(curl -fsSL https://get.chezmoi.io)" -- -b ~/.local/bin

# 3. Point chezmoi at this repo's chezmoi/ folder as its source, and set
#    this machine's name for dot_zshrc.tmpl's per-machine sections:
mkdir -p ~/.config/chezmoi
cat > ~/.config/chezmoi/chezmoi.toml <<EOF
sourceDir = "$HOME/code/homelab/chezmoi"

[data]
    machine = "<geekom-linux|mba13-mac|mbp16-mac|...>"
EOF

# 4. Apply — writes .zshrc/.p10k.zsh/.gitconfig/.vimrc into ~/:
~/.local/bin/chezmoi apply

# 5. .vimrc references vim-plug, which isn't chezmoi-managed (external
#    tool, same convention as Oh My Zsh) — install it, then install the
#    plugins it declares:
curl -fLo ~/.vim/autoload/plug.vim --create-dirs \
  https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim
vim -es -u ~/.vimrc -c "PlugInstall --sync" -c "qa"
```

`~/.config/chezmoi/chezmoi.toml` itself is not tracked here — it's the
one small bootstrap step every machine needs before chezmoi knows
where to find its source directory and what its `machine` name is.

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

Tracked: `.zshrc`, `.p10k.zsh`, `.gitconfig`, `.vimrc` — config with no
secrets in it. Also `.ssh/authorized_keys` (**only** this one file under
`.ssh/`, as `private_dot_ssh/private_authorized_keys` — the `private_`
prefix preserves `.ssh`'s `700`/`authorized_keys`'s `600` permissions on
apply) — it's just public keys, safe to track, but **differs per
machine** (each host authorizes different peers), so unlike the shared
dotfiles above it isn't meant to be applied identically everywhere.
Currently only geekom's is tracked; see `TODO.md` for extending this to
`mba13-linux`/`mbp16-mac`.

**Not** tracked, and shouldn't be added: anything else under `.ssh/`
(private keys, `known_hosts`, `config`), `.gnupg/`, anything under
`.config/` with API keys/tokens, shell history files, caches
(`.zcompdump*`, `.cache/`), or other app-generated state. If in doubt
before `chezmoi add`-ing something, check it for embedded secrets
first.
