---
title: "Add a scpme alias, same idea as sshme"
status: open
created: 2026-09-03
updated: 2026-09-03
tags: [dotfiles, chezmoi, aliases]
---

Per-machine, host-less — `scp -i <that machine's own tailnet identity
key>` — so you append source/target yourself, same as `sshme`. Add to
`dot_zshrc.tmpl`'s per-machine branches alongside the existing `sshme`
entries.
