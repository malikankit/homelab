# issues/

Flat folder of individual open work items — the replacement for
`TODO.md`'s "Low priority" list. One file per issue, kebab-case
filename. See `ai-learning/learning-while-doing/issues-in-the-age-of-claude.md`
for the reasoning behind file-based issues over a database-backed
tracker, for this specific repo.

## Convention

Each issue is a single Markdown file with frontmatter:

```yaml
---
title: "..."
status: open        # open | blocked | closed
created: YYYY-MM-DD
updated: YYYY-MM-DD  # bump every time the file is edited
tags: [kebab-case, tags]
---
```

Body: context/description up top (what and why), then an appended,
chronological **Progress** section as work happens on it — each entry
dated, newest at the bottom. Don't rewrite history in place; append.
This is the file-based equivalent of an issue's comment thread.

- **`status: open`** — not started, or intermittently worked on.
- **`status: blocked`** — actively investigated, currently stuck on
  something specific (a decision, an external dependency, a user
  action). Say plainly what it's blocked on, at the top of the file.
- **`status: closed`** — resolved. Leave the file in place (don't
  delete) as a record of what was tried and how it was fixed, same as a
  closed GitHub issue stays readable. If it becomes actively
  misleading later (the fix gets reverted, etc.), update it — don't
  just leave stale "closed" state.

## When to use this vs. `ai-learning`'s `suspended-contexts/`

- **`issues/` (here, in `homelab`)** — an actionable task specific to
  this repo/infrastructure: a bug, a cleanup, a decision that needs
  making, a feature to add. Tied to homelab's own state.
- **`ai-learning/suspended-contexts/`** — a paused *investigation* or
  *build effort* with real accumulated context worth preserving in
  detail (debugging history, options considered, why), especially one
  that might span multiple sessions of active back-and-forth before
  resolving. Often coexists with an `issues/` entry here that just
  points at it, the way `TODO.md` used to.

Rule of thumb: if it's a single clear action once someone gets to it,
it's an issue. If it needs a "here's everything we tried and why"
narrative to resume properly, write that narrative in
`suspended-contexts/` and keep the issue file here short with a link.
