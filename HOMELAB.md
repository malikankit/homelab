# Homelab Overview

This repo documents setup across all machines in the homelab. Per-machine
detail lives in each machine's own subfolder (`geekom/`, `mba13/`,
`mbp16/`); this file is the cross-machine picture — network topology,
trust model, and SSH access map.

## Machines

| Physical name | Tailnet hostname | Repo folder | OS | AM-tailnet IP |
|---|---|---|---|---|
| geekom | am6 | `geekom/` | Ubuntu 26.04 (desktop) | `100.78.110.5` |
| mba13 | am-ma | `mba13/` | Asahi Linux (2nd partition — mba13 dual-boots macOS + Asahi; `am-ma` is the tailnet identity of the Asahi boot, not macOS) | `100.105.210.109` |
| mbp16 | ams-mbp16 | `mbp16/` | macOS | `100.87.74.44` (also has a separate Zenith-network IP, `100.108.204.52`, when logged into Zenith instead) |

"Physical name" is how the machine is referred to day to day; "Tailnet
hostname" is what shows up in `tailscale status` / DNS names like
`am6.tail6e8877.ts.net`. IPs above are on the **AM** network — see below
for why a machine can have a different IP on Zenith.

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
`am-ma` are hardened that way (see `geekom/tailscale_setup.md`) — the same
should carry over to `mbp16` too.

**Firewall policy: per-machine IP allowlist, not tailnet-wide.** Rather
than "allow SSH from any device on the tailnet," each machine's firewall
allows port 22 only from the specific AM-tailnet IPs of the other 2
machines above (`am-ma`'s ufw was already set up this way; `geekom`'s
`ufw_rules.sh` was updated to match). This is stricter than tailnet
membership alone — a device merely joining the tailnet, or an ACL
misconfiguration, doesn't grant SSH reachability by itself. New machine →
new IP added to the allowlist on every existing machine it needs to reach.

## SSH access map

| From \ To          | am6 (geekom)        | am-ma (mba13)        | ams-mbp16 (mbp16) |
|---------------------|----------------------|------------------------|--------------------|
| **am6 (geekom)**    | —                    | key added, blocked by am-ma's ufw allowlist (am6's IP not yet added) | not yet            |
| **am-ma (mba13)**   | not yet              | —                      | not yet            |
| **ams-mbp16 (mbp16)** | yes (authorized)   | yes (authorized)       | —                  |

`ams-mbp16` currently has inbound SSH authorized on both `am6` and
`am-ma`. `am6` → `am-ma`: the key is in `am-ma`'s `authorized_keys`, but
`am-ma`'s ufw allowlist doesn't include `am6`'s IP (`100.78.110.5`) yet —
needs `sudo ufw allow in on tailscale0 from 100.78.110.5 to any port 22
proto tcp comment 'SSH from am6'` on `am-ma`. Cells are updated as access
is actually granted — this table reflects real reachability, not intent.

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

| Machine | openssh-server | ufw (per-machine IP allowlist) | sshd key-only auth | Tailscale SSH off |
|---|---|---|---|---|
| am6 (geekom) | done | done (allowlist: am-ma, ams-mbp16) | done | confirmed off |
| am-ma (mba13) | yes (working) | yes, but am6 not yet added to allowlist | TBD — review pending | TBD — review pending |
| ams-mbp16 (mbp16) | TBD | TBD | TBD | TBD |

`geekom/tailscale_setup.md`, `geekom/ufw_rules.sh`,
`geekom/sshd_hardening.sh`, `geekom/test_ssh_setup.sh` are the reusable
pattern. `am-ma` is Linux (Asahi) like `geekom`, so the same `ufw`/`sshd`
tooling applies directly — only `mbp16` (macOS) needs different tooling
(Application Firewall / `pf` instead of `ufw`).
