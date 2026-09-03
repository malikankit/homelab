---
title: "DNS status: investigate Tailscale health warning on mba13-linux"
status: open
created: 2026-09-03
updated: 2026-09-03
tags: [tailscale, dns, mba13-linux]
---

`tailscale status` on mba13-linux reports: `Tailscale can't reach the
configured DNS servers. Internet connectivity may be affected.` Root
cause unknown yet — check `resolvectl status`, what DNS servers
Tailscale/MagicDNS is configured to use (admin console DNS settings vs.
what's actually reachable from mba13-linux), and whether this is related
to or separate from the MagicDNS short-hostname resolution issue seen on
geekom (short name `mba13-linux` didn't resolve there, but the Tailscale
IP worked fine).
