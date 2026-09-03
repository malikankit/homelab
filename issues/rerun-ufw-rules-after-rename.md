---
title: "Re-run ufw_rules.sh on geekom-linux and mba13-linux after the hostname rename"
status: open
created: 2026-09-03
updated: 2026-09-03
tags: [ufw, geekom, mba13, cosmetic]
---

The scripts' comments/variable names were updated in the repo to the new
Tailnet names (`am6`→`geekom-linux`, `am-ma`→`mba13-linux`,
`ams-mbp16`→`mbp16-mac`, renamed 2026-08-22), but the *live* ufw rules on
each machine still carry the old comment text (IPs are unchanged, so
connectivity isn't affected — this is cosmetic only). Run
`sudo ./ufw_rules.sh` on `geekom-linux` and on `mba13-linux` to bring the
live comments in sync. See `HOMELAB.md` changelog for the full list of
what else was renamed in this pass.
