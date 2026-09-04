---
title: "Design /check-in, /check-out skills, and a feedback-nudge habit"
status: open
created: 2026-09-03
updated: 2026-09-03
tags: [claude-code, skills, memory, feedback, planning-only]
---

**Explicitly parked** — pick this back up once the current diarization
work (the 99-minute kiran-ankit file, running in the background) is
done and settled. Not blocked on anything external, just deprioritized
behind that.

## Context

Came up after Claude gave critical feedback on the day's session when
asked directly (saved to `ai-learning/learning-while-doing/feedback-from-claude.md`,
2026-09-03 entry). Follow-up question: how to make that kind of
feedback a recurring habit — nudging when a known pattern recurs,
without costing meaningful context window over time — plus two
proposed new skills to formalize the daily rhythm.

## The nudge mechanism (mostly already exists, not a new build)

Claude's persistent memory system already has a "feedback" memory type
built for exactly this — durable guidance that gets recalled without
needing to be repeated. Real, checked numbers on cost: `MEMORY.md` (the
always-loaded index) is one line per memory, ~150 chars capped — even
15-20 feedback memories total ~500-700 tokens, roughly 0.05-0.07% of a
1M-token window. Individual memory files only load into context when
judged relevant, not wholesale every session.

Two separate mechanisms, two purposes, worth keeping distinct:
- **Memory (feedback type)** — Claude's own low-cost behavioral nudge,
  read passively when relevant.
- **`ai-learning/learning-while-doing/feedback-from-claude.md`** —
  human-readable, git-tracked, meant for the user to read back over
  time. Not auto-loaded into context every session (would get
  expensive as it grows) — read deliberately, e.g. during a
  `/check-out` comparison pass.

Gap named but not yet resolved: memory nudges passively (Claude tries
to recall relevant ones). Whether Claude should *proactively* call out
"this looks like a recurring pattern" the moment it's noticed, versus
just applying the lesson silently — a behavioral commitment, not new
infra, but worth deciding explicitly rather than assuming.

## `/check-out` (end of day) — proposed scope, not yet decided

1. Write the actions/outcomes/epiphanies journal entry (same shape as
   the 2026-09-03 one).
2. If feedback is requested: read the *previous* `feedback-from-claude.md`
   entry first and explicitly compare — did a named pattern recur, did
   it improve — rather than a fresh, disconnected critique each time.
3. An open-issues digest as part of the same report — what's open/
   blocked in `issues/`, what's sitting in `ai-learning/suspended-contexts/`.

**Open question**: is the feedback section on-by-default every
check-out, or only when explicitly asked (today's pattern)? Always-on
risks feeling like an unrequested report card; on-request is opt-in
but relies on remembering to ask.

## `/check-in` (start of session/day) — proposed scope, not yet decided

Read `issues/` (open/blocked) + `ai-learning/suspended-contexts/`, give
a concise "here's what's pending, here's what's blocked and on what" —
without the user having to ask for a digest explicitly each time.

**Open question**: should it flag staleness (e.g. "open 7+ days") once
there's been enough time for that to mean something, or stay a flat
list for now?

## Other undecided design questions

- **Scope**: user-level skills (work in any project, like the existing
  `/capture-learning`) or homelab-project-level? Leaning user-level
  since the *habit* is general even though today's content is
  homelab-specific — not decided.
- Both should run **in the current session's own context**, not a
  fresh subagent — a fresh agent has zero memory of the actual day's
  conversation and would need to somehow re-ingest it, defeating the
  purpose. Same pattern `/capture-learning` already uses.

## Not yet done

Nothing built. This file is the parking lot for the whole discussion —
resume once diarization work is done and settled.
