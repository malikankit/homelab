---
title: "Extend chezmoi tracking of authorized_keys to mba13-linux and mbp16-mac"
status: open
created: 2026-09-03
updated: 2026-09-03
tags: [chezmoi, ssh, dotfiles]
---

Only geekom's `~/.ssh/authorized_keys` is chezmoi-managed so far
(`chezmoi/private_dot_ssh/private_authorized_keys`). The other two
hosts' files weren't accessible to add from geekom directly — needs
running `chezmoi add ~/.ssh/authorized_keys` on mba13-linux and
mbp16-mac themselves (after `chezmoi.toml` is pointed at this repo's
`chezmoi/` there), or pasting their current contents in so they can be
added remotely. Since content differs per host, this can't just reuse
geekom's file as-is — either keep per-host source files (e.g.
`machine`-suffixed) or a `.tmpl` branching like `dot_zshrc.tmpl` does.
See `chezmoi/README.md`'s "What's tracked here vs. not".
