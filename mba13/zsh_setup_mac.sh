#!/usr/bin/env bash
# Set up zsh on mba13-mac (macOS boot of mba13) to match geekom-linux's
# setup: Oh My Zsh + Powerlevel10k + the same plugin set, with .zshrc /
# .p10k.zsh / .gitconfig managed by chezmoi (source: ../chezmoi/ in this
# same repo clone — see ../chezmoi/README.md). See ../geekom/zsh_setup.md
# for the reference setup this mirrors.
#
# Self-contained: run this from a clone of the homelab repo already on
# this machine (mba13/todo_mba13-mac_onboard.md step 0).
#
# Idempotent: safe to re-run; skips anything already cloned/installed.
# chezmoi apply overwrites ~/.zshrc, ~/.p10k.zsh, ~/.gitconfig with the
# repo's managed versions — back them up first if you have uncommitted
# local edits to any of those three files.
#
# Usage: ./zsh_setup_mac.sh

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CHEZMOI_SOURCE="$REPO_ROOT/chezmoi"

if [[ ! -d "$CHEZMOI_SOURCE" ]]; then
  echo "ERROR: $CHEZMOI_SOURCE not found — is this a clone of the homelab repo?" >&2
  exit 1
fi

ZSH_CUSTOM="$HOME/.oh-my-zsh/custom"

# --- Oh My Zsh (non-interactive: doesn't touch default shell or launch zsh) ---
if [[ -d "$HOME/.oh-my-zsh" ]]; then
  echo "Oh My Zsh already installed — skipping."
else
  RUNZSH=no CHSH=no KEEP_ZSHRC=yes sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
fi

# --- Plugins + theme ---
clone_if_missing() {
  local repo="$1" dest="$2"
  if [[ -d "$dest" ]]; then
    echo "Already present: $dest — skipping."
  else
    git clone --depth=1 "$repo" "$dest"
  fi
}

clone_if_missing https://github.com/zsh-users/zsh-autosuggestions "$ZSH_CUSTOM/plugins/zsh-autosuggestions"
clone_if_missing https://github.com/zsh-users/zsh-syntax-highlighting "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting"
clone_if_missing https://github.com/zsh-users/zsh-completions "$ZSH_CUSTOM/plugins/zsh-completions"
clone_if_missing https://github.com/romkatv/powerlevel10k.git "$ZSH_CUSTOM/themes/powerlevel10k"

# --- fzf ---
if [[ -d "$HOME/.fzf" ]]; then
  echo "fzf already present — skipping clone."
else
  git clone --depth=1 https://github.com/junegunn/fzf.git "$HOME/.fzf"
fi
"$HOME/.fzf/install" --key-bindings --completion --no-update-rc --no-bash --no-fish

# --- chezmoi ---
if [[ -x "$HOME/.local/bin/chezmoi" ]]; then
  echo "chezmoi already installed — skipping."
else
  sh -c "$(curl -fsSL https://get.chezmoi.io)" -- -b "$HOME/.local/bin"
fi

mkdir -p "$HOME/.config/chezmoi"
cat > "$HOME/.config/chezmoi/chezmoi.toml" <<EOF
sourceDir = "$CHEZMOI_SOURCE"

[data]
    machine = "mba13-mac"
EOF

echo
echo "chezmoi diff (preview of what's about to change in \$HOME):"
"$HOME/.local/bin/chezmoi" diff
echo
"$HOME/.local/bin/chezmoi" apply -v

echo
echo "Done. ~/.zshrc, ~/.p10k.zsh, ~/.gitconfig are now chezmoi-managed."
echo "Edit them via the source files in $CHEZMOI_SOURCE, then 'chezmoi diff' / 'chezmoi apply'."
if [[ "$SHELL" != *zsh* ]]; then
  echo "Current login shell is $SHELL — run 'chsh -s $(which zsh)' to make zsh"
  echo "default (needs your account password; log out/in after)."
else
  echo "zsh is already your login shell."
fi
echo "If Powerlevel10k icons look wrong, run 'p10k configure' (needs a Nerd Font in your terminal app)."
