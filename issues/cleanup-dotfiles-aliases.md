---
title: "Clean up dotfiles/aliases.sh after the 2026-09-01 \"Add aliases\" commit"
status: open
created: 2026-09-03
updated: 2026-09-03
tags: [dotfiles, chezmoi, aliases]
---

Restore `ll`/`la`/`l`/`egrep --color=auto`/`alert`, which look like they
were accidentally removed. Move `shix`/`sham` out — they duplicate
existing per-machine aliases in `dot_zshrc.tmpl` (which point at each
machine's own key) with a hardcoded one that won't exist on every
machine. Move `shag` (uses mbp16-mac's Zenith-only key) and `obsidian`
(currently inside an `echo "..."` so it never actually defines an alias,
and uses macOS-only `open -a`) into the right per-machine blocks instead
of the shared file. Keep `pserver`/`whichserver`/`va`/`p3`/`brave-debug()`
where they are — those are fine shared as-is.

See commit `7e05e01` for the minimal syntax fix already applied (just
closed an unclosed brace).
