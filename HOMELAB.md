# Homelab Overview

This repo documents setup across all machines in the homelab. Per-machine
detail lives in each machine's own subfolder (`geekom/`, `mba13/`,
`mbp16/`); this file is the cross-machine picture — network topology,
trust model, and SSH access map. Open follow-ups live in `TODO.md`.

## Machines

| Physical name | Tailnet hostname | Tailscale short name | Repo folder | OS | AM-tailnet IP |
|---|---|---|---|---|---|
| geekom | geekom-linux | `6l` | `geekom/` | Ubuntu 26.04 (desktop) | `100.78.110.5` |
| mba13 | mba13-linux | `13l` | `mba13/` | Asahi Linux (2nd partition — mba13 dual-boots macOS + Asahi; `mba13-linux` is the tailnet identity of the Asahi boot, not macOS) | `100.105.210.109` |
| mba13 | mba13-mac | `13m` | `mba13/` | macOS (1st partition — the other boot of the same physical machine as `mba13-linux`) | on the AM Tailscale network; **outbound-only** — "Disable incoming connections" is on in the Tailscale app, so it can SSH out to other hosts but nothing can SSH into it; see `mba13/todo_mba13-mac_onboard.md` |
| mbp16 | mbp16-mac | `16m` | `mbp16/` | macOS | `100.87.74.44` (also has a separate Zenith-network IP, `100.108.204.52`, when logged into Zenith instead) |

"Physical name" is how the machine is referred to day to day; "Tailnet
hostname" is what shows up in `tailscale status`'s hostname column
historically and is used throughout this repo/`chezmoi`'s `machine` data
value (see `chezmoi/README.md`). "Tailscale short name" is the current,
shorter device name set in the Tailscale admin console (renamed after the
hostname migration this repo otherwise documents) — it's what
`tailscale status` and MagicDNS names actually show today, e.g.
`6l.seahorse-enigmatic.ts.net`. `seahorse-enigmatic.ts.net` is this
tailnet's MagicDNS/cert domain (HTTPS Certificates enabled) — used for
any `tailscale serve`/Caddy TLS work (see `services/`). IPs above are on
the **AM** network — see below for why a machine can have a different IP
on Zenith.

## Tailscale networks

Devices sometimes move between two separate tailnets — treat them as two
different trust levels, not interchangeable:

- **AM Tailscale Network** — admin: me. Only my own devices are on it.
  Default/primary network for these 3 machines.
- **Zenith Tailscale Network** — admin: someone else. May have other
  users on it besides me.

**Trust implication**: on the AM network, the tailnet ACLs/policy are
something I control and can rely on. On Zenith, I don't control the ACLs
and don't fully trust `acl.conf` or other users on that network — so
whatever security posture a machine has must hold up on its own, without
assuming the tailnet is a trusted perimeter. In practice this means:
**host-level hardening — firewall scoped to a per-machine IP allowlist on
the `tailscale0` interface, plus SSH key-only auth with Tailscale SSH left
off — is the actual security boundary**, not "which tailnet am I on right
now" or "is this device on the tailnet at all." This is why `geekom` and
`mba13-linux` are hardened that way (see `geekom/tailscale_setup.md`) — the same
should carry over to `mbp16` too.

**Caveat (2026-08-21): the ufw half of this boundary doesn't currently
hold.** `tailscaled` inserts its own `ts-input` iptables chain ahead of
ufw's chains and accepts Tailscale-interface traffic before ufw ever
runs — confirmed empirically (SSH from an unallowlisted IP succeeded).
Real reachability today is actually governed by Tailscale's own ACL
policy (default: allow-all between tailnet devices) plus sshd's
key-only auth, not by the per-machine ufw allowlist below. See
`knowledge/tailscale_ufw_bypass.md` for the full writeup and fix
options — not yet decided, tracked in `TODO.md`.

**Firewall policy: per-machine IP allowlist, not tailnet-wide.** Rather
than "allow SSH from any device on the tailnet," each machine's firewall
allows port 22 only from the specific AM-tailnet IPs of the other 2
machines above (`mba13-linux`'s ufw was already set up this way; `geekom`'s
`ufw_rules.sh` was updated to match). This is stricter than tailnet
membership alone — a device merely joining the tailnet, or an ACL
misconfiguration, doesn't grant SSH reachability by itself. New machine →
new IP added to the allowlist on every existing machine it needs to reach.

## SSH access map

| From \ To          | geekom-linux (geekom)        | mba13-linux (mba13)        | mbp16-mac (mbp16) | mba13-mac (mba13) |
|---------------------|----------------------|------------------------|--------------------|--------------------|
| **geekom-linux (geekom)**    | —                    | key added, blocked by mba13-linux's ufw allowlist (geekom-linux's IP not yet added) | not yet            | n/a — mba13-mac is inbound-blocked |
| **mba13-linux (mba13)**   | yes (authorized)     | —                      | not yet            | n/a — mba13-mac is inbound-blocked |
| **mbp16-mac (mbp16)** | yes (authorized)   | yes (authorized)       | —                  | n/a — mba13-mac is inbound-blocked |
| **mba13-mac (mba13)** | yes (authorized)   | not yet       | n/a                  | — |

`mbp16-mac` currently has inbound SSH authorized on both `geekom-linux` and
`mba13-linux`. `mba13-linux` → `geekom-linux`: `mba13-linux`'s outbound key
(`mba13-linux_to_tailnet_ed25519.pub`) is authorized in `geekom-linux`'s
`authorized_keys` — this was already live but missing from this table
until it was noticed and reconciled here. `geekom-linux` → `mba13-linux`: the key is in `mba13-linux`'s `authorized_keys`, but
`mba13-linux`'s ufw allowlist doesn't include `geekom-linux`'s IP (`100.78.110.5`) yet —
needs `sudo ufw allow in on tailscale0 from 100.78.110.5 to any port 22
proto tcp comment 'SSH from geekom-linux'` on `mba13-linux`. `mba13-mac` is
**outbound-only by design** (Tailscale's "Disable incoming connections" is
on) — it will never have a "To" column, and other machines don't need it
added to their ufw allowlists since nothing needs to reach in. Cells are
updated as access is actually granted — this table reflects real
reachability, not intent.

## SSH key inventory

Per-machine `.pub` files are checked into each machine's folder purely so
they're easy to copy-paste into another machine's `authorized_keys` —
private keys never leave the machine they were generated on.

| Key file | Machine | Purpose |
|---|---|---|
| `geekom/id_ed25519.pub` | geekom-linux | GitHub only — **not** used to authorize SSH into any host |
| `geekom/geekom-linux_to_tailnet_ed25519.pub` | geekom-linux | geekom-linux → other AM-tailnet hosts |
| `mbp16/id_ed25519.pub` | mbp16-mac | GitHub only |
| `mbp16/id_rsa.pub` | mbp16-mac | mbp16-mac → other AM-tailnet hosts (currently authorized on geekom-linux, mba13-linux) |
| `mbp16/aa_am_ed25519.pub` | mbp16-mac | Login to Zenith network only |
| `mba13/mba13-mac_to_tailnet.pub` | mba13-mac | mba13-mac → other AM-tailnet hosts (currently authorized on geekom-linux). Outbound only — mba13-mac itself has no inbound key to authorize since nothing SSHes into it. |
| `mba13/mba13-linux_to_tailnet_ed25519.pub` | mba13-linux | mba13-linux → other AM-tailnet hosts (currently authorized on geekom-linux) |

Convention going forward: **one key per trust boundary** (GitHub vs.
inter-host AM-tailnet SSH vs. Zenith), never reused across boundaries.
Rationale: a leak or rotation in one boundary shouldn't affect the
others, and none of these keys should ever be used with agent forwarding
into a machine outside their intended boundary.

## Per-machine hardening status

| Machine | openssh-server | ufw (per-machine IP allowlist) | sshd key-only auth | Tailscale SSH off |
|---|---|---|---|---|
| geekom-linux (geekom) | done | done (allowlist: mba13-linux, mbp16-mac) | done | confirmed off |
| mba13-linux (mba13) | yes (working) | yes, but geekom-linux not yet added to allowlist | TBD — review pending | TBD — review pending |
| mbp16-mac (mbp16) | TBD | TBD | TBD | TBD |
| mba13-mac (mba13) | n/a — outbound-only, no inbound sshd needed | n/a — Tailscale's "Disable incoming connections" blocks all inbound at the Tailscale layer instead | n/a | TBD — belt-and-suspenders check pending, see `mba13/todo_mba13-mac_onboard.md` |

`geekom/tailscale_setup.md`, `geekom/ufw_rules.sh`,
`geekom/sshd_hardening.sh`, `geekom/test_ssh_setup.sh` are the reusable
pattern. `mba13-linux` is Linux (Asahi) like `geekom`, so the same `ufw`/`sshd`
tooling applies directly — only `mbp16` and `mba13-mac` (macOS) need
different tooling (Application Firewall / `pf` instead of `ufw`).

## Changelog

- **2026-08-25 — Reconciled `mba13-linux` → `geekom-linux` access, doc
  was stale.** While fixing a stale comment in geekom's
  `~/.ssh/authorized_keys` (still read `am-ma-tailnet@...`, the
  pre-rename identity), found that `mba13-linux`'s outbound key was
  already present and live there — contradicting this table's "not
  yet" entry for that path. Confirmed intentional; updated the SSH
  access map and added the missing `mba13-linux_to_tailnet_ed25519.pub`
  row to the key inventory table (it was never added when the key was
  actually granted).

- **2026-08-22 — mba13-mac scoped to outbound-only.** Decided mba13-mac
  will never be SSH'd into, only used to SSH out to other AM-tailnet
  hosts. Confirmed via Tailscale's own "Disable incoming connections"
  toggle (macOS app), which blocks all inbound tailnet traffic at the
  Tailscale layer. This removes the need for macOS Application
  Firewall/`pf` allowlist scripting, inbound sshd key-only hardening,
  and adding mba13-mac's IP to other machines' `ufw` allowlists — those
  only mattered for inbound reachability. Updated
  `mba13/todo_mba13-mac_onboard.md`, the Machines/SSH access
  map/hardening-status tables above, and `TODO.md` to match. zsh setup
  and outbound SSH to geekom-linux (via the new
  `mba13/mba13-mac_to_tailnet.pub` key, authorized on geekom-linux) are
  both confirmed working.

- **2026-08-22 — Tailnet hostname migration.** Renamed all three
  Tailscale device names for clarity (physical name + OS, matching
  `mba13-mac`'s naming ahead of its onboarding):
  - `am6` → `geekom-linux`
  - `am-ma` → `mba13-linux`
  - `ams-mbp16` → `mbp16-mac`

  Changes made:
  - Renamed the devices in Tailscale (`tailscale set --hostname=...` /
    admin console) — IPs unchanged, only the name.
  - Updated all references across this repo (docs, scripts, comments).
  - Renamed the inter-host SSH key files/comments to match:
    `geekom/am6_to_tailnet_ed25519(.pub)` →
    `geekom/geekom-linux_to_tailnet_ed25519(.pub)`,
    `mba13/am-ma_to_tailnet_ed25519(.pub)` →
    `mba13/mba13-linux_to_tailnet_ed25519(.pub)`. Renamed the matching
    live private/public key files in `~/.ssh/` on both `geekom-linux` and
    `mba13-linux` (over SSH for geekom-linux), and updated each key's
    embedded comment via `ssh-keygen -c`. Keypairs themselves were **not**
    regenerated — only filenames/comments changed, so existing
    `authorized_keys` entries stay valid.
  - `ufw_rules.sh` on both `geekom/` and `mba13/` had their allowlist
    comments and shell variable names (`AM_MA_IP` → `MBA13_LINUX_IP`,
    etc.) updated to match. **Not yet re-applied live** — re-running
    `sudo ./ufw_rules.sh` needs an interactive sudo password on each
    machine, so this is tracked in `TODO.md` rather than done here.
  - Added a `mba13-mac` row to the Machines table above (onboarding not
    yet done — see `mba13/todo_mba13-mac_onboard.md`).
