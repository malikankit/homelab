#!/usr/bin/env bash
# basic_setup.sh — machine bootstrap for the AM homelab, shared across
# machines (currently mba13-mac and mbp16-mac; see ../HOMELAB.md for
# what each machine name maps to). Detects which machine it's running
# on from the hostname, then walks through each setup section one at a
# time — each section explains what it's about to change and asks for
# confirmation before running, so you can decline ones you don't want
# right now and just rerun the script later for the rest.
#
# Idempotent: every section is safe to re-run; each skips whatever it's
# already done.
#
# Self-contained: run this from a clone of the homelab repo already on
# this machine.
#
# Add new setup steps here over time — wrap each in its own
# section_<name> function and a run_section call at the bottom, same
# pattern as the existing ones.
#
# Usage: ./basic_setup.sh

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CHEZMOI_SOURCE="$REPO_ROOT/chezmoi"

if [[ ! -d "$CHEZMOI_SOURCE" ]]; then
  echo "ERROR: $CHEZMOI_SOURCE not found — is this a clone of the homelab repo?" >&2
  exit 1
fi

# ── Machine detection ────────────────────────────────────────────────
# Only mba13-mac/mbp16-mac are recognized so far. Falls back to an
# explicit prompt if the hostname doesn't confidently match either —
# never guesses silently.
detect_machine() {
  local name=""
  if command -v scutil >/dev/null 2>&1; then
    name="$(scutil --get ComputerName 2>/dev/null || true)"
  fi
  [[ -z "$name" ]] && name="$(hostname -s 2>/dev/null || true)"

  name="$(printf '%s' "$name" | tr '[:upper:]' '[:lower:]')"
  case "$name" in
    *mba13*) echo "mba13-mac" ;;
    *mbp16*) echo "mbp16-mac" ;;
    *) echo "" ;;
  esac
}

MACHINE="$(detect_machine)"
if [[ -z "$MACHINE" ]]; then
  echo "Couldn't confidently detect which machine this is from its hostname."
  echo "Known machines: mba13-mac, mbp16-mac (see ../HOMELAB.md)."
  read -rp "Which machine is this? " MACHINE
else
  echo "Detected machine: $MACHINE"
  read -rp "Is this correct? [Y/n] " confirm_machine
  if [[ "$confirm_machine" =~ ^[Nn] ]]; then
    read -rp "Enter the correct machine name: " MACHINE
  fi
fi
echo

# ── Section-confirmation helper ─────────────────────────────────────
run_section() {
  local title="$1" description="$2" func="$3"
  echo "── $title ──────────────────────────────────────"
  echo "$description"
  read -rp "Run this section? [Y/n] " ans
  if [[ "$ans" =~ ^[Nn] ]]; then
    echo "Skipped."
    echo
    return
  fi
  "$func"
  echo
}

clone_if_missing() {
  local repo="$1" dest="$2"
  if [[ -d "$dest" ]]; then
    echo "Already present: $dest — skipping."
  else
    git clone --depth=1 "$repo" "$dest"
  fi
}

# ── Sections ──────────────────────────────────────────────────────────

section_ohmyzsh() {
  # Cloned directly (not via the official install.sh, which is fetched
  # from raw.githubusercontent.com — blocked on some ISPs). ~/.oh-my-zsh
  # being this clone is all the installer itself actually sets up; it
  # otherwise also touches ~/.zshrc and offers chsh, both of which we
  # skip here on purpose (chezmoi manages .zshrc, chsh happens manually,
  # see the end of this script).
  clone_if_missing https://github.com/ohmyzsh/ohmyzsh.git "$HOME/.oh-my-zsh"
}

section_zsh_plugins() {
  local zsh_custom="$HOME/.oh-my-zsh/custom"
  clone_if_missing https://github.com/zsh-users/zsh-autosuggestions "$zsh_custom/plugins/zsh-autosuggestions"
  clone_if_missing https://github.com/zsh-users/zsh-syntax-highlighting "$zsh_custom/plugins/zsh-syntax-highlighting"
  clone_if_missing https://github.com/zsh-users/zsh-completions "$zsh_custom/plugins/zsh-completions"
  clone_if_missing https://github.com/romkatv/powerlevel10k.git "$zsh_custom/themes/powerlevel10k"
}

section_fzf() {
  if [[ -d "$HOME/.fzf" ]]; then
    echo "fzf already present — skipping clone."
  else
    git clone --depth=1 https://github.com/junegunn/fzf.git "$HOME/.fzf"
  fi
  "$HOME/.fzf/install" --key-bindings --completion --no-update-rc --no-bash --no-fish
}

section_chezmoi() {
  if [[ -x "$HOME/.local/bin/chezmoi" ]]; then
    echo "chezmoi already installed — skipping."
  else
    sh -c "$(curl -fsSL https://get.chezmoi.io)" -- -b "$HOME/.local/bin"
  fi

  mkdir -p "$HOME/.config/chezmoi"
  cat > "$HOME/.config/chezmoi/chezmoi.toml" <<EOF
sourceDir = "$CHEZMOI_SOURCE"

[data]
    machine = "$MACHINE"
EOF

  echo "chezmoi diff (preview of what's about to change in \$HOME):"
  "$HOME/.local/bin/chezmoi" diff
  echo
  "$HOME/.local/bin/chezmoi" apply -v
}

section_vim_plugins() {
  if [[ -f "$HOME/.vim/autoload/plug.vim" ]]; then
    echo "vim-plug already installed — skipping."
  else
    # Cloned (github.com) rather than curl'd from raw.githubusercontent.com
    # (blocked on some ISPs) — vim-plug is just the single plug.vim file
    # in this repo, so clone to a scratch dir and copy it out.
    local tmpdir
    tmpdir="$(mktemp -d)"
    git clone --depth=1 https://github.com/junegunn/vim-plug.git "$tmpdir"
    mkdir -p "$HOME/.vim/autoload"
    cp "$tmpdir/plug.vim" "$HOME/.vim/autoload/plug.vim"
    rm -rf "$tmpdir"
  fi
  vim -es -u "$HOME/.vimrc" -c "PlugInstall --sync" -c "qa"
}

section_sshfs() {
  # FUSE-T instead of macFUSE — deliberately, not the "default" choice.
  # macFUSE needs a kernel extension, which on Apple Silicon requires
  # Reduced Security enabled via Recovery Mode's Startup Security
  # Utility before macOS will even offer the approval prompt — and on a
  # machine that dual-boots Asahi Linux, getting Recovery Mode to edit
  # *macOS's* policy specifically (each boot volume group has its own
  # independent policy) turned out not to work in practice. FUSE-T
  # implements the same FUSE interface via a macOS Network Extension
  # instead of a kernel extension — just a plain System Settings
  # approval, no Recovery Mode, no kext hassle, no interaction with
  # whatever else is dual-booted on the machine.
  if brew list --cask fuse-t >/dev/null 2>&1; then
    echo "FUSE-T already installed — skipping."
  else
    brew install --cask macos-fuse-t/homebrew-cask/fuse-t
    echo
    echo "FUSE-T needs one-time approval: System Settings -> Privacy &"
    echo "Security -> Allow the network extension prompt, if one appears."
    echo "The first actual mountg run also triggers a macOS \"local"
    echo "network\" permission prompt (for the sshfs process itself) --"
    echo "approve that too. No Recovery Mode step needed either way."
    echo
  fi

  # FUSE-T's own sshfs build (not gromgit/fuse/sshfs-mac, which is
  # built against macFUSE specifically).
  if command -v sshfs >/dev/null 2>&1; then
    echo "sshfs already installed — skipping."
  else
    brew install macos-fuse-t/homebrew-cask/fuse-t-sshfs
  fi
}

# ── Run ───────────────────────────────────────────────────────────────

run_section "Oh My Zsh" \
  "Installs Oh My Zsh non-interactively — won't touch your default shell or launch zsh." \
  section_ohmyzsh

run_section "zsh plugins + Powerlevel10k" \
  "Clones zsh-autosuggestions, zsh-syntax-highlighting, zsh-completions, and the Powerlevel10k theme into ~/.oh-my-zsh/custom." \
  section_zsh_plugins

run_section "fzf" \
  "Clones fzf and installs its key-bindings/completion (no shell rc changes — .zshrc already sources it)." \
  section_fzf

run_section "chezmoi (.zshrc / .p10k.zsh / .gitconfig / .vimrc)" \
  "Installs chezmoi, points it at this repo's chezmoi/ folder with machine=\"$MACHINE\", then applies — this OVERWRITES ~/.zshrc, ~/.p10k.zsh, ~/.gitconfig, ~/.vimrc with the repo's managed versions. Back up any uncommitted local edits to those files first." \
  section_chezmoi

run_section "vim-plug + Markdown-preview plugins" \
  "Installs vim-plug and runs :PlugInstall for the plugins .vimrc declares (previm, open-browser.vim)." \
  section_vim_plugins

run_section "sshfs (mount geekom's ~/code as ~/6l/code)" \
  "Installs FUSE-T + sshfs via Homebrew, for the mountg/umountg aliases in .zshrc. FUSE-T needs a one-time System Settings approval (no Recovery Mode/kext hassle) before it actually works (instructions printed if this is a fresh install)." \
  section_sshfs

echo "Done."
if [[ "$SHELL" != *zsh* ]]; then
  echo "Current login shell is $SHELL — run 'chsh -s $(which zsh)' to make zsh"
  echo "default (needs your account password; log out/in after)."
else
  echo "zsh is already your login shell."
fi
echo "If Powerlevel10k icons look wrong, run 'p10k configure' (needs a Nerd Font in your terminal app)."

# Hand off to a fresh zsh so whatever chezmoi/section_chezmoi just wrote
# to .zshrc (new aliases, etc.) is live immediately in this same
# terminal — this script's own process can't change *your* shell's
# already-loaded environment otherwise, only a new one starting fresh
# picks it up. Exiting this new shell (Ctrl+D / `exit`) drops you back
# into whatever shell you originally ran this script from.
if command -v zsh >/dev/null 2>&1; then
  echo
  echo "Starting a fresh zsh so new aliases are live in this terminal..."
  exec zsh
fi
