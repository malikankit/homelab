# Powerlevel10k instant prompt — disabled along with the theme below.
# Uncomment if re-enabling Powerlevel10k.
# if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
#   source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
# fi

# ═══════════════════════════════════════════════════════
# Auto-attach tmux on SSH login
# ═══════════════════════════════════════════════════════
# Only fires for an incoming SSH session (not geekom's own desktop
# terminal) that isn't already inside tmux. `exec` replaces this shell
# with the tmux client so there's no leftover outer shell process;
# `new-session -A -s main` attaches to the "main" session if it already
# exists (e.g. from a previous SSH session) or creates it if not — so
# reconnecting drops you back where you left off, and work started
# under one SSH session survives a dropped connection.
if [[ -n "$SSH_CONNECTION" ]] && [[ -z "$TMUX" ]]; then
  exec tmux new-session -A -s main
fi

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
# PATH
# ═══════════════════════════════════════════════════════
if [ -d "${HOME}/.local/bin" ] && [[ ":${PATH}:" != *":${HOME}/.local/bin:"* ]]; then
    PATH="${HOME}/.local/bin:${PATH}"
fi

# ═══════════════════════════════════════════════════════
# Remote-session background color — visual "you're on geekom" flag
# ═══════════════════════════════════════════════════════
# Only fires when this shell was reached via SSH (not a local login), so
# it doesn't recolor geekom's own desktop terminal — only a terminal
# that's SSH'd in from elsewhere. Uses OSC 11 (set background color),
# supported by iTerm2, kitty, alacritty, wezterm, foot, etc. macOS
# Terminal.app doesn't support it — this is a harmless no-op there, not
# an error. Restores the terminal's own background on shell exit (OSC 111).
if [[ -n "$SSH_CONNECTION" ]]; then
  printf '\033]11;#fdf6e3\007'
  trap 'printf "\033]111\007"' EXIT
fi

# ═══════════════════════════════════════════════════════
# Aliases — shared ones live in the homelab repo, one copy for every
# machine (see dotfiles/README.md for the convention).
# ═══════════════════════════════════════════════════════
[ -f ~/code/homelab/dotfiles/aliases.sh ] && source ~/code/homelab/dotfiles/aliases.sh

# Machine-specific (not in the shared file)
alias sham="ssh -i ~/.ssh/am6_to_tailnet_ed25519 am@100.105.210.109"
