---
title: "tmux mouse scroll cycles Claude Code prompt history instead of scrolling output"
status: blocked
created: 2026-09-03
updated: 2026-09-03
tags: [tmux, claude-code, terminal, mouse, mba13-mac]
---

**Blocked on**: unclear why the documented fix didn't work. Needs
further investigation (likely another `claude-code-guide` agent pass,
or direct experimentation) before a next step can even be proposed.

## Context

Started as a simple "how do I scroll up in this tmux/Claude Code window"
question, on mba13-mac, running Claude Code inside tmux over SSH.

## What was tried, in order

1. **Initial advice given** (not tmux-specific, turned out insufficient
   on its own): Fn+Up/Down for Page Up/Down on a Mac laptop keyboard;
   `Ctrl+b [` to enter tmux copy-mode, then arrows/`q` to exit.

2. **Checked tmux mouse mode** — found `mouse off` (`tmux show -g
   mouse`). Root filesystem confirmed plain `ext4 defaults`, no
   quota-related config relevant here. Concluded trackpad scroll wasn't
   wired to anything in tmux at all.

3. **Enabled `set -g mouse on`** in `chezmoi/dot_tmux.conf`, applied via
   `chezmoi apply` + `tmux source-file ~/.tmux.conf`, committed + pushed
   (`homelab` commit `c33c60b`). Result: trackpad scroll started doing
   *something*, but the wrong thing — it began cycling through past
   input-box prompts (like shell readline history) instead of scrolling
   conversation output.

4. **Diagnosed via a `claude-code-guide` subagent** (had it check
   official Claude Code docs). Its finding: Claude Code's TUI does *not*
   use the terminal's alternate-screen buffer, and has no built-in
   scroll-back keybinding in normal mode by design (it always
   auto-follows to the bottom). The prompt-cycling symptom was
   attributed to tmux falling back to translating mouse-wheel scroll
   into Up/Down arrow keypresses (because extended-key/mouse-passthrough
   negotiation wasn't configured), which Claude Code's input box then
   reads as history recall. Cited fix, from Claude Code's own docs
   (`https://code.claude.com/docs/en/terminal-config.md#configure-tmux`):
   ```
   set -g allow-passthrough on
   set -s extended-keys on
   set -as terminal-features 'xterm*:extkeys'
   ```
   Also noted: normal TUI mode has no scrollback of its own by design;
   `/tui fullscreen` switches to a renderer where PageUp/PageDown (and
   mouse scroll) work natively over the conversation itself.

5. **Applied the documented fix** — added the three lines to
   `chezmoi/dot_tmux.conf`, `chezmoi apply` + `tmux source-file`,
   committed + pushed (`homelab` commit `3b2184f`).

6. **User ran `/tui fullscreen`** — Claude Code's own response noted
   "Background sessions always use the fullscreen renderer while
   attached" (implying it may already have been active). **Scrolling
   still cycled through prompt history** — the fix did not resolve the
   symptom.

## Where this stands

The documented tmux fix (`allow-passthrough`, `extended-keys`,
`terminal-features`) did not resolve the issue after being applied +
`tmux source-file`'d + confirmed present in `tmux show -g`/`show -s`
(not independently re-verified after the fix — worth re-checking that
the settings actually took effect before assuming the fix itself is
wrong). Possible next directions, none investigated yet:

- Some tmux terminal-capability negotiation may require a **fresh client
  attach** (new SSH connection / new tmux client), not just
  `source-file`, to take effect — `terminal-features` in particular is
  negotiated at attach time in some tmux versions.
- The **client-side terminal app** (iTerm2, presumably, on mba13-mac)
  may need its own settings changed (e.g. explicit xterm mouse reporting
  mode) independent of the tmux-side config — untested.
- Could be specific to this being a **background Claude Code session**
  (per the `/tui fullscreen` response's own wording) vs. one started
  directly with `claude` — untested whether the behavior differs there.
- Worth trying **without tmux at all** (direct SSH, no multiplexer) as a
  control, to isolate whether this is tmux-specific or something about
  Claude Code + this specific terminal/SSH setup more broadly.

## Not yet tried
Nothing beyond the above — parked here deliberately rather than
continuing to guess at a fourth config change blind.
