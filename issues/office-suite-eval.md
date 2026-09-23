---
title: "Pick a self-hosted office suite (CryptPad / OnlyOffice / Collabora CODE)"
status: open
created: 2026-09-23
updated: 2026-09-23
tags: [geekom, services, cryptpad, onlyoffice, collabora, office-suite]
---

Trying three self-hostable office suites in practice, on geekom, before
picking one for good: **CryptPad** (lightest, fully self-contained,
end-to-end encrypted — going first), **OnlyOffice Docs** (best Excel
format fidelity, but pairs with Nextcloud and has a 2026 licensing
controversy — mobile editing moved behind a paid `license.dat`), and
**Collabora CODE** (strong formula engine, fully open source, no known
phone-home/licensing gate). See `services/cryptpad_setup_log.md` for
the full narrative of what's been done so far.

Also the first real instance of a routing decision made for all future
services on geekom: one dedicated `tailscale serve` port per service,
not subdomains (Tailscale certs are per-device only) and not a shared
Caddy path (a future Tailscale ACL policy — see
`issues/tailscale-ufw-bypass-fix.md` — can only restrict by `host:port`,
not HTTP path).

## Progress

- **2026-09-23**: CryptPad deployed at `services/cryptpad/`
  (`6l.seahorse-enigmatic.ts.net:8443` main / `:8444` sandbox). Hit and
  fixed several setup bugs (port clash with Forgejo, a wrong internal
  "sandbox port" assumption, missing `CPAD_CONF`, a bad `config/`
  directory mount, UID/permission errors, and a login-salt file that
  crashed the client's boot sequence with `ReferenceError: AppConfig is
  not defined` — full detail in `services/cryptpad_setup_log.md`).
  Server-side fully verified via `curl` (HTTP 200 on the page and every
  asset, valid cert, successful WebSocket upgrade). **Not yet confirmed
  working in an actual browser** after the last fix — waiting on that
  before moving on to admin-account creation and locking down
  registration.

## Remaining steps

1. Confirm `https://6l.seahorse-enigmatic.ts.net:8443/` actually loads
   end-to-end in a real browser (private window, not just `curl`).
2. Create the admin account, grab the account's public signing key, add
   it to `adminKeys`.
3. Lock down public registration from the admin panel.
4. Create a real doc/sheet/presentation from a peer machine, confirm
   editing/saving works.
5. `free -h` before/after, to start tracking real RAM cost ahead of
   adding a second candidate alongside it.
6. Repeat steps 1-5 for OnlyOffice Docs (paired with Nextcloud) and
   Collabora CODE, each on their own `tailscale serve` ports.
7. Decide which one to keep; tear down the other two (or keep more than
   one if they end up serving genuinely different needs — e.g. CryptPad
   for quick encrypted notes vs. OnlyOffice for real `.xlsx` work).
8. Fold the winner's port(s) into the Tailscale ACL policy once that
   gets written (`issues/tailscale-ufw-bypass-fix.md`).
