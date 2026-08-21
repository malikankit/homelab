#!/usr/bin/env bash
# Set up zsh on mbp16-mac to match geekom-linux's setup: Oh My Zsh +
# Powerlevel10k + the same plugin set. See ../geekom/zsh_setup.md for the
# reference setup this mirrors.
#
# Self-contained: run this from a clone of the homelab repo already on
# this machine. It pulls ~/.p10k.zsh straight from ../geekom/zshrc_backup/
# in this same repo clone — no manual file copying from geekom needed.
#
# Idempotent: safe to re-run; skips anything already cloned/installed,
# and backs up any existing ~/.zshrc / ~/.p10k.zsh before overwriting.
#
# Usage: ./zsh_setup_mac.sh

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
P10K_SRC="$REPO_ROOT/geekom/zshrc_backup/.p10k.zsh"

if [[ ! -f "$P10K_SRC" ]]; then
  echo "ERROR: $P10K_SRC not found — is this a clone of the homelab repo?" >&2
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

# --- Back up any existing config before overwriting ---
TS="$(date +%Y%m%d_%H%M%S)"
[[ -f "$HOME/.zshrc" ]] && cp "$HOME/.zshrc" "$HOME/.zshrc.bak.$TS"
[[ -f "$HOME/.p10k.zsh" ]] && cp "$HOME/.p10k.zsh" "$HOME/.p10k.zsh.bak.$TS"

cp "$P10K_SRC" "$HOME/.p10k.zsh"

cat > "$HOME/.zshrc" <<'EOF'
# Enable Powerlevel10k instant prompt. Should stay close to the top of ~/.zshrc.
# Initialization code that may require console input (password prompts, [y/n]
# confirmations, etc.) must go above this block; everything else may go below.
# Powerlevel10k instant prompt — disabled along with the theme below.
# Uncomment if re-enabling Powerlevel10k.
# if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
#   source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
# fi

# ═══════════════════════════════════════════════════════
# Oh My Zsh
# ═══════════════════════════════════════════════════════
export ZSH="$HOME/.oh-my-zsh"

# Powerlevel10k disabled in favor of a plain bash-style prompt (see below) —
# no icons/Nerd Font/terminal-escape-sequence support needed, works
# identically in every terminal. Set back to "powerlevel10k/powerlevel10k"
# any time to re-enable it (also uncomment the instant-prompt block above
# and the source line in the Prompt section below).
ZSH_THEME=""

plugins=(
  git
  z
  fzf
  zsh-autosuggestions
  zsh-syntax-highlighting   # must stay last in this list
  zsh-completions
)

source $ZSH/oh-my-zsh.sh

# ═══════════════════════════════════════════════════════
# Prompt — plain bash-style: user@host:path$
# ═══════════════════════════════════════════════════════
# Powerlevel10k is still installed (~/.p10k.zsh) but disabled above in
# favor of this. Re-enable by setting ZSH_THEME back above and
# uncommenting the line below (plus the instant-prompt block at the top).
# [[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh
PROMPT='%n@%m:%~$ '

# ═══════════════════════════════════════════════════════
# fzf (Ctrl+R history search, Ctrl+T file find, Alt+C cd)
# ═══════════════════════════════════════════════════════
[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh

# ═══════════════════════════════════════════════════════
# Aliases
# ═══════════════════════════════════════════════════════
alias ll='ls -alF'
alias la='ls -A'
alias l='ls -CF'
alias grep='grep --color=auto'
alias fgrep='fgrep --color=auto'
alias egrep='egrep --color=auto'

# Homelab
alias hl="cd ~/code/homelab"
alias hlp="cd ~/code/homelab/mbp16/"
alias cr="claude --resume"

# SSH to other AM-tailnet hosts — uses mbp16-mac's existing inter-host key
# (see ../HOMELAB.md SSH key inventory: mbp16/id_rsa.pub, already
# authorized on geekom-linux and mba13-linux).
alias sshg="ssh -i ~/.ssh/id_rsa am@100.78.110.5"       # geekom-linux
alias sshm="ssh -i ~/.ssh/id_rsa am@100.105.210.109"    # mba13-linux
EOF

echo
echo "Done. ~/.zshrc and ~/.p10k.zsh are in place."
if [[ "$SHELL" != *zsh* ]]; then
  echo "Current login shell is $SHELL — run 'chsh -s $(which zsh)' to make zsh"
  echo "default (needs your account password; log out/in after)."
else
  echo "zsh is already your login shell."
fi
echo "If Powerlevel10k icons look wrong, run 'p10k configure' (needs a Nerd Font in your terminal app)."
