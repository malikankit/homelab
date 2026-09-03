---
title: "Set up LiveSync + CouchDB for Obsidian, alongside obsidian-git"
status: open
created: 2026-09-03
updated: 2026-09-03
tags: [obsidian, geekom, services, couchdb]
---

Per `gitandansiblesetupplan.md`'s Phase 2 options table: `obsidian-git`
gives full Git history but only scheduled (not real-time) sync, with
partial mobile support (Android via isomorphic-git; iOS more limited).
LiveSync adds real-time sync + full mobile support but no version
history on its own — the two don't conflict, so this layers LiveSync on
top of the existing `obs`/`llmwiki` repos rather than replacing
`obsidian-git`.

Needs: CouchDB deployed on geekom (new `services/couchdb/`, same
outside-repo state convention as the others), exposed only over
Tailscale (same pattern as Forgejo — no raw port on a real interface),
and the LiveSync community plugin configured on each device.
