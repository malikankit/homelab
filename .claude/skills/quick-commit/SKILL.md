---
name: quick-commit
description: "Fast git commit + push for this homelab repo, skipping the full review workflow (no separate diff/log review calls, no back-and-forth). Use when the user says '/quick-commit', 'quick commit', or just wants current changes committed and pushed without ceremony."
---

Low-stakes personal repo — skip the elaborate multi-step commit workflow. Do this in as few tool calls as possible:

1. `git status` once, to see what's changed.
2. Stage only files that are clearly intentional changes (skip anything that looks like a stray/temp file, or ask in one line if genuinely ambiguous). Never stage files previously called out as "do not commit" (check recent conversation context).
3. Write a short, plain commit message (1 line, imperative mood — no need for a body unless the change is non-obvious).
4. Commit and push in the same breath — `git commit -m "..." && git push`. Don't run a separate `git diff` or `git log` pass first; `git status` is enough context for a repo this small and low-risk.
5. Report the result in one line (commit hash + where it pushed). No summary paragraph.

If `git push` fails or is blocked, say so plainly and stop — don't retry with `--force` or bypass hooks.
