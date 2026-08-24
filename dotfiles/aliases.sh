# Shared aliases — sourced from ~/.bashrc / ~/.zshrc on every machine.
# POSIX-safe: no zsh-only or bash-only syntax, so it works identically
# under both shells. Machine-specific aliases (e.g. a host-specific SSH
# shortcut) stay local in that machine's own rc file, not here.

alias ll='ls -alF'
alias la='ls -A'
alias l='ls -CF'
alias grep='grep --color=auto'
alias fgrep='fgrep --color=auto'
alias egrep='egrep --color=auto'
alias alert='notify-send --urgency=low -i "$([ $? = 0 ] && echo terminal || echo error)" "$(history|tail -n1|sed -e '\''s/^\s*[0-9]\+\s*//;s/[;&|]\s*alert$//'\'')"'

# Homelab repo shortcuts — assumes the repo is cloned at ~/code/homelab
# on every machine (the convention this repo already uses).
alias hl="cd ~/code/homelab"
alias hlg="cd ~/code/homelab/geekom/"

alias cr="claude --resume"
