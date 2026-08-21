# zsh setup (geekom)

Switched geekom's interactive shell from bash to zsh: Oh My Zsh +
Powerlevel10k + a standard productivity plugin set. Config backups live in
`zshrc_backup/` in this folder (`.zshrc`, `.p10k.zsh`) — restore by copying
them back to `~/`.

## What's installed

- **Oh My Zsh** — cloned to `~/.oh-my-zsh` (not backed up here; it's a git
  clone of https://github.com/ohmyzsh/ohmyzsh, reproducible from scratch).
- **Powerlevel10k** theme — `~/.oh-my-zsh/custom/themes/powerlevel10k`
  (https://github.com/romkatv/powerlevel10k).
- **zsh-autosuggestions** — fish-style inline suggestions from history.
- **zsh-syntax-highlighting** — colors valid/invalid commands as you type
  (must stay last in `plugins=(...)` in `.zshrc`).
- **zsh-completions** — extra completion definitions.
- **fzf** — Ctrl+R fuzzy history search, Ctrl+T fuzzy file-find, Alt+C fuzzy
  cd. Cloned to `~/.fzf`, installed with `--key-bindings --completion
  --no-update-rc` (rc wiring is manual, in `.zshrc`, not fzf's installer).
- **z** and **git** — bundled with Oh My Zsh, no separate install.

## Reproducing from scratch on another machine

```bash
# Oh My Zsh (non-interactive, doesn't touch default shell or launch zsh)
RUNZSH=no CHSH=no KEEP_ZSHRC=yes sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended

ZSH_CUSTOM="$HOME/.oh-my-zsh/custom"
git clone --depth=1 https://github.com/zsh-users/zsh-autosuggestions "$ZSH_CUSTOM/plugins/zsh-autosuggestions"
git clone --depth=1 https://github.com/zsh-users/zsh-syntax-highlighting "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting"
git clone --depth=1 https://github.com/zsh-users/zsh-completions "$ZSH_CUSTOM/plugins/zsh-completions"
git clone --depth=1 https://github.com/romkatv/powerlevel10k.git "$ZSH_CUSTOM/themes/powerlevel10k"

git clone --depth=1 https://github.com/junegunn/fzf.git ~/.fzf
~/.fzf/install --key-bindings --completion --no-update-rc --no-bash --no-fish

cp zshrc_backup/.zshrc ~/.zshrc
cp zshrc_backup/.p10k.zsh ~/.p10k.zsh
```

Then make zsh the login shell (needs the account's password — `chsh` prompts
for it itself, no sudo required since zsh is already listed in
`/etc/shells`):
```bash
chsh -s $(which zsh)
```
Log out/in for it to take effect. A terminal's Nerd-Font setting (for
Powerlevel10k's icons) is a terminal-app setting, not something this backup
covers — re-run `p10k configure` on a fresh machine if icons look wrong.

## Note on ~/.bashrc

Personal aliases (`sham`, `hl`, `hlg`, `cr`, plus the standard `ll`/`la`/`l`/
`grep --color` ones) were migrated into `.zshrc` — bash is still installed
and `~/.bashrc` is untouched/still valid as a fallback, just no longer the
default login shell.
