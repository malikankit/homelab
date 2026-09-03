---
title: "mba13: formalize sshd hardening as a script"
status: open
created: 2026-09-03
updated: 2026-09-03
tags: [mba13-linux, ssh, security]
---

mba13-linux already has key-only SSH working via a pre-existing drop-in
(`/etc/ssh/sshd_config.d/10-key-only.conf`, dated Feb 9 2026, not tracked
in this repo), but two settings don't match geekom's baseline:
`AuthenticationMethods` is `any` (geekom: `publickey`, declared not just
implicit) and `PermitRootLogin` is `prohibit-password` (geekom: `no`).

Write `mba13/sshd_hardening.sh` mirroring `geekom/sshd_hardening.sh`
(backup/apply/verify pattern) and align those two directives.
