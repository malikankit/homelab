---
title: "Gate Bash-tool reads of credential files (not just the Read tool)"
status: open
created: 2026-09-03
updated: 2026-09-03
tags: [claude-code, security, credentials, hooks, permissions]
---

## Context

Came up right after a real incident: Claude accidentally `cat`'d a Hugging
Face OAuth token file (`~/.cache/huggingface/token`) via the **Bash**
tool while checking auth status, when a non-secret-revealing check (like
`hf auth whoami`) would have answered the same question. The token got
printed into the conversation transcript as a result.

As a first fix, added `permissions.deny` rules to `~/.claude/settings.json`
(user-level) blocking the `Read` tool from touching common credential
file patterns — HF token cache, generic `token`/`credentials` files,
`.netrc`, `~/.aws/credentials`, and common SSH private key naming
patterns (excluding `.pub` files). See `homelab` commit history around
2026-09-03 for the exact rule set.

## The gap

**`permissions.deny` `Read(...)` rules only gate the structured `Read`
tool — they do nothing for the `Bash` tool.** `Read` and `Bash` are
separate permission namespaces. The actual incident happened via
`Bash(cat ...)`, which the new deny rules would **not** have prevented.
Bash-based `cat`/`head`/`less`/`tail`/a script reading the file — none
of that is touched by the current fix.

## What's needed

A `PreToolUse` hook matched on the `Bash` tool that inspects the command
string for credential-file-like paths (the same pattern list used in the
`Read` deny rules, or a shared one) and blocks/asks before the command
runs. More robust than trying to enumerate exact `Bash(...)` permission
rules (which only support prefix-match patterns and can't generalize
across different invocations of the same underlying risk — `cat X`,
`less X`, `head X`, a Python one-liner reading X, etc. would all need
separate, brittle exact-match rules).

This is also related to an earlier, broader idea floated in this repo:
gating `Read`/`Bash` access to files *outside the current project
directory* entirely (came up when Claude was reading files under
`~/models/`, `~/transcripts/`, `~/code/files-from-mac/` — all outside
`homelab`). The credential-file case here is a specific, higher-priority
instance of that same general need. Worth deciding whether to build one
hook covering both, or two narrower ones.

## Not yet done

No hook written yet. Parked deliberately — noted as a real gap
immediately after the `Read`-only fix landed, rather than treated as
solved.
