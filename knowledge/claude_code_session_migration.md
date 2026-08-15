# Migrating Claude Code sessions between machines

Context: migrating dev folders from am-ma's `~/code/` to geekom's
`~/code/`, and wanting to `/resume` the old Claude Code conversations for
those projects on the new machine.

## How Claude Code session storage works

Sessions are keyed to a project by its **absolute filesystem path**, not
by machine identity, and stored purely locally — no cloud sync involved.
Transcripts live at:

```
~/.claude/projects/<mangled-path>/
```

where `<mangled-path>` is the project's absolute path with every `/`
replaced by `-`. Example: `/home/am/code/homelab` becomes
`-home-am-code-homelab` (this is literally this project's own session
storage path).

## What's required for `/resume` to work on a different machine

1. **The absolute path must match exactly** on the new machine. If a
   project lives at `/home/am/code/<project>` on am-ma, it needs to land
   at that exact same path on geekom (same username, same layout) — not
   just "somewhere under `~/code/`".
2. **Two things move together, not just the code**:
   - The project folder itself.
   - Its matching `~/.claude/projects/<mangled-path>/` directory (the
     actual session transcripts).
3. If the path differs in any way (different nesting, casing, home
   directory layout), Claude Code treats it as a different project and
   the old sessions won't show up under `/resume` — there's no fuzzy
   matching or manual re-linking.

## Recommended transfer method

Use `rsync`/`scp` over the Tailscale SSH already set up between these
machines (see `HOMELAB.md`, `geekom/tailscale_setup.md`) — key-only auth,
firewall scoped to the known machine IPs. Session transcripts can contain
real code and output from past work, so this is exactly the kind of
transfer that setup exists for.

For each project being migrated, transfer both:
```
~/code/<project>
~/.claude/projects/<mangled-path-of-that-project>
```
to the identical paths on the destination machine.

## Automated: `mba13/migrate_project.sh`

Interactive script (run on am-ma) that lists top-level project folders
under `~/code`, dry-runs + confirms an rsync of both the code and its
matching session directory to am6, logs a succinct per-project report to
`mba13/logs/migrations/`, and offers to move a migrated project into
`~/code/migrated_to_am6/` afterward to declutter — a local move, not a
deletion. Loops until you're done, so it handles a batch of projects in
one run.
