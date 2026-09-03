---
title: "geekom: reclaim disk space from duplicated model downloads"
status: open
created: 2026-09-03
updated: 2026-09-03
tags: [geekom, disk-usage, cleanup, huggingface-cache]
---

`~/.cache/huggingface/hub/` has 116G across two Qwen models
(`Qwen/Qwen3.8-27B-FP8`, `orcarouter/Qwen3.8-27B-Uncensored-FP8`, ~29G
each), and `~/models/backups/` has a second, apparently identical 29G
copy of each — 4 copies total, unrelated to the `tools/hindi_translation`
work. Also a redundant 2.9G copy of `Trelis/tara` sitting in the HF cache
alongside the real `~/models/tara` the script actually uses.

Needs a decision: keep one copy of each Qwen model (reclaim ~58G) or
confirm they're unused entirely (reclaim ~116G) — not yet determined
whether these models are still needed for anything active.

Smaller, unconditionally-safe cleanup identified alongside this:
`~/.cache/pip` (4.3G, regenerable), `~/.cache/tracker3` (531M),
`~/.cache/gnome-software` (107M), and two scratch `.wav` files in
`~/code/files-from-mac/` (205M, regenerable from their `.m4a` originals).

Full findings: `ai-learning` repo,
`suspended-contexts/2026-09-03-disk-cleanup-findings.md`.
