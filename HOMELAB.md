# Homelab Overview

This repo documents setup across all machines in the homelab. Per-machine
detail lives in each machine's own subfolder (`geekom/`, `mba13/`,
`mbp16/`); this file is the cross-machine picture — network topology,
trust model, and SSH access map.

## Machines

| Physical name | Tailnet hostname | Repo folder | OS      |
|----------------|-------------------|-------------|---------|
| geekom         | am6               | `geekom/`   | Ubuntu 26.04 (desktop) |
| mba13          | am-ma             | `mba13/`    | macOS   |
| mbp16          | ams-mbp16         | `mbp16/`    | macOS   |

All three are joined to the tailnet below by default. "Physical name" is
how the machine is referred to day to day; "Tailnet hostname" is what
shows up in `tailscale status` / `tailscale status --json` / DNS names
like `am6.tail6e8877.ts.net`.

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
**host-level hardening (firewall scoped to the `tailscale0` interface +
SSH key-only auth, no Tailscale SSH) is the actual security boundary**,
not "which tailnet am I on right now." This is why `geekom` was hardened
that way (see `geekom/tailscale_setup.md`) — the same approach should
carry over to `mba13` and `mbp16` regardless of which tailnet they're
connected to at a given moment.

## SSH access map

| From \ To          | am6 (geekom)        | am-ma (mba13)        | ams-mbp16 (mbp16) |
|---------------------|----------------------|------------------------|--------------------|
| **am6 (geekom)**    | —                    | pending (this session) | not yet            |
| **am-ma (mba13)**   | not yet              | —                      | not yet            |
| **ams-mbp16 (mbp16)** | yes (authorized)   | yes (authorized)       | —                  |

`ams-mbp16` currently has inbound SSH authorized on both `am6` and
`am-ma`. `am6` → `am-ma` access is being set up now (dedicated key, see
below). Cells are updated as access is actually granted — this table
reflects real `authorized_keys` state, not intent.

## SSH key inventory

Per-machine `.pub` files are checked into each machine's folder purely so
they're easy to copy-paste into another machine's `authorized_keys` —
private keys never leave the machine they were generated on.

| Key file | Machine | Purpose |
|---|---|---|
| `geekom/id_ed25519.pub` | am6 | GitHub only — **not** used to authorize SSH into any host |
| `geekom/am6_to_tailnet_ed25519.pub` | am6 | am6 → other AM-tailnet hosts |
| `mbp16/id_ed25519.pub` | ams-mbp16 | GitHub only |
| `mbp16/id_rsa.pub` | ams-mbp16 | ams-mbp16 → other AM-tailnet hosts (currently authorized on am6, am-ma) |
| `mbp16/aa_am_ed25519.pub` | ams-mbp16 | Login to Zenith network only |

Convention going forward: **one key per trust boundary** (GitHub vs.
inter-host AM-tailnet SSH vs. Zenith), never reused across boundaries.
Rationale: a leak or rotation in one boundary shouldn't affect the
others, and none of these keys should ever be used with agent forwarding
into a machine outside their intended boundary.

## Per-machine hardening status

| Machine | openssh-server | ufw (SSH scoped to `tailscale0` only) | sshd key-only auth | Tailscale SSH off |
|---|---|---|---|---|
| am6 (geekom) | done | done | done | confirmed off |
| am-ma (mba13) | TBD | TBD | TBD | TBD |
| ams-mbp16 (mbp16) | TBD | TBD | TBD | TBD |

See `geekom/tailscale_setup.md`, `geekom/ufw_rules.sh`,
`geekom/sshd_hardening.sh`, `geekom/test_ssh_setup.sh` for the pattern
used on am6 — reusable as-is for the other two once reviewed/adapted per
OS (macOS's firewall/`sshd` tooling differs from Ubuntu's `ufw`).
