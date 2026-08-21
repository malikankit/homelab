# Enable Powerlevel10k instant prompt. Should stay close to the top of ~/.zshrc.
# Initialization code that may require console input (password prompts, [y/n]
# confirmations, etc.) must go above this block; everything else may go below.
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

# ═══════════════════════════════════════════════════════
# Oh My Zsh
# ═══════════════════════════════════════════════════════
export ZSH="$HOME/.oh-my-zsh"

ZSH_THEME="powerlevel10k/powerlevel10k"

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
# Powerlevel10k
# ═══════════════════════════════════════════════════════
# Run `p10k configure` any time to redo this interactively.
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh

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
# Aliases (migrated from ~/.bashrc)
# ═══════════════════════════════════════════════════════
alias ll='ls -alF'
alias la='ls -A'
alias l='ls -CF'
alias grep='grep --color=auto'
alias fgrep='fgrep --color=auto'
alias egrep='egrep --color=auto'
alias alert='notify-send --urgency=low -i "$([ $? = 0 ] && echo terminal || echo error)" "$(history|tail -n1|sed -e '\''s/^\s*[0-9]\+\s*//;s/[;&|]\s*alert$//'\'')"'

# Ankit Aliases
alias sham="ssh -i ~/.ssh/am6_to_tailnet_ed25519 am@100.105.210.109"
alias hl="cd ~/code/homelab"
alias hlg="cd ~/code/homelab/geekom/"
alias cr="claude --resume"
