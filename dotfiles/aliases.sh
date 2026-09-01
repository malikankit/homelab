# Shared aliases — sourced from ~/.bashrc / ~/.zshrc on every machine.
# POSIX-safe: no zsh-only or bash-only syntax, so it works identically
# under both shells. Machine-specific aliases (e.g. a host-specific SSH
# shortcut) stay local in that machine's own rc file, not here.

alias grep='grep --color=auto'
alias fgrep='fgrep --color=auto'
#
#
# Homelab repo shortcuts — assumes the repo is cloned at ~/code/homelab
# on every machine (the convention this repo already uses).
alias hl="cd ~/code/homelab"
alias hlg="cd ~/code/homelab/geekom/"

alias cr="claude --resume"
alias shix="ssh -i ~/.ssh/id_rsa am@100.78.110.5"       # geekom-linux
alias shag="ssh -i ~/.ssh/aa_am_ed25519 ankitmalik@zenithankit-pc"
alias sham="ssh mba13-linux"
alias pserver="python3 -m http.server 8000"
alias whichserver="lsof -i :8000"

alias va="source ./venv/bin/activate"
alias p3="python3"

brave-debug() {
osascript -e 'quit app "Brave Browser"' 2>/dev/null
while pgrep -x "Brave Browser" >/dev/null; do sleep 0.3; done
open -na "Brave Browser" --args --remote-debugging-port=9222 --profile-directory="Profile 88"
alias aliases="vi ~/code/homelab/dotfiles/aliases.sh"
echo "alias obsidian='open -a Obsidian'"
