---
title: "tmux: make Caps Lock act as a second prefix key alongside Ctrl+b"
status: open
created: 2026-09-03
updated: 2026-09-03
tags: [tmux, karabiner, keybindings]
---

On the Macs, Karabiner Elements now remaps Caps Lock to a held ⌘⌃⌥⇧
modifier chord (no keycode of its own — it only does anything combined
with another key). Want e.g. Caps Lock+`:` to open tmux's command prompt
the same way Ctrl+b then `:` does today, without breaking Ctrl+b.

Complication: since Caps Lock alone sends no keystroke, "Caps Lock + key"
arrives at tmux as a single chorded key event (e.g.
Cmd-Ctrl-Opt-Shift-`:`), not two sequential events the way Ctrl+b then
`:` does — so this likely can't be a generic `prefix2`, and instead
needs individual `bind -n <chord+key>` entries in tmux.conf for each
prefix command actually used, each mapped to what `prefix + <key>`
currently does. Also need to confirm whether the terminal app (iTerm2 on
both Macs, presumably) actually forwards Cmd-modified key combos to the
shell at all, since terminals normally reserve Cmd for their own menu
shortcuts. Needs the user's Karabiner config / terminal key-passthrough
settings before this can be implemented correctly.
