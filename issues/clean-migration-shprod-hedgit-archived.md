---
title: "Clean migration for shprod and hedgit_archived"
status: open
created: 2026-09-03
updated: 2026-09-03
tags: [migration, mba13-linux, geekom]
---

Both failed via `migrate_project.sh` on 2026-08-16, leaving
partial/incomplete directories on geekom-linux (rsync errored partway
through). Those partial copies have been deleted from geekom-linux —
originals on mba13-linux are untouched (cleanup was never offered for
failed runs). `shprod` has noticeably tighter permissions (`750`) than
the other projects (`775`), possibly a read-permission issue on some
file — worth capturing the actual rsync error text (the migration log
only records pass/fail) before retrying.
