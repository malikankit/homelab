# Tailscale bypasses ufw's per-machine allowlist

Discovered 2026-08-21 while verifying whether geekom's ufw allowlist would
block an SSH attempt from mba13-mac (whose IP isn't in the allowlist).

## The finding

`tailscaled` inserts its own `ts-input` chain **ahead of every ufw chain**
in the `INPUT` table:

```
$ sudo iptables -L INPUT -n --line-numbers
Chain INPUT (policy DROP)
num  target     prot opt source               destination
1    ts-input   all  --  0.0.0.0/0            0.0.0.0/0
2    ufw-before-logging-input  ...
3    ufw-before-input  ...
...
```

And `ts-input` itself accepts traffic before it ever reaches ufw's rules:

```
$ sudo iptables -L ts-input -n --line-numbers
Chain ts-input (1 references)
num  target     prot opt source               destination
1    ACCEPT     all  --  100.78.110.5         0.0.0.0/0
2    ACCEPT     all  --  0.0.0.0/0            0.0.0.0/0
3    ACCEPT     udp  --  0.0.0.0/0            0.0.0.0/0            udp dpt:41641
4    RETURN     all  --  100.115.92.0/23      0.0.0.0/0
5    DROP       all  --  100.64.0.0/10        0.0.0.0/0
```

Rule 2 is a blanket accept for traffic arriving over the Tailscale
interface. Net effect: **`geekom/ufw_rules.sh`'s per-machine IP allowlist
(`ufw allow in on tailscale0 from <IP> to any port 22 ...`) never gets
evaluated for Tailscale traffic** — `ts-input` already accepted the
packet first. This was confirmed empirically: mba13-mac's IP was not in
geekom's ufw allowlist, yet SSH from mba13-mac to geekom succeeded.

This is Tailscale's documented design intent, not a bug: Tailscale's own
security model is "tailnet membership + Tailscale ACL policy," and it
expects *you* to do access control via Tailscale ACLs (in the admin
console), not via a host firewall on the `tailscale0` interface.

## What this means for the trust model in `../HOMELAB.md`

`HOMELAB.md` documents host-level hardening (ufw per-machine allowlist +
SSH key-only auth) as the real security boundary, especially for Zenith
(other admin, other users — tailnet ACLs there aren't fully trusted).
**The ufw half of that boundary is not currently doing its job** for
traffic arriving over any Tailscale network, AM or Zenith. In practice,
reachability is actually governed by:

1. **Tailscale network membership** — only devices on the tailnet can
   address the machine at all. Solid; not affected by this bypass.
2. **Tailscale ACL policy** — Tailscale's *default* policy (unless a
   custom `acl.json` has been written in the admin console) is "allow
   all devices to reach all ports on all other devices." If unchanged,
   any device on the tailnet — not just the ones in
   `geekom/ufw_rules.sh`'s allowlist — can reach port 22 (and every
   other port) on geekom.
3. **sshd key-only auth** — still fully real and working (verified via
   `geekom/sshd_hardening.sh`: password/keyboard-interactive disabled).
   A connection that reaches sshd still needs a private key matching
   `authorized_keys`, or it's refused. This is the layer actually
   preventing unauthorized logins today — not ufw.

## What's *not* affected

This bypass is specific to traffic arriving via the `tailscale0`
interface. ufw's default-deny-incoming still applies normally to other
interfaces (LAN/`eth0`, wifi) — a direct SSH attempt from the LAN or
public internet (not via Tailscale) is still blocked by ufw as designed,
and none of these machines have router port-forwarding exposing SSH to
the public internet in the first place, so there's no direct path in
from outside the tailnet at all.

## Fix options (not yet decided — see `../TODO.md`)

- **Write actual Tailscale ACLs** in the admin console scoping which
  devices can reach which ports on which other devices (e.g., only
  mba13-linux/mbp16-mac → geekom:22). This fixes it at the layer that's
  actually in control of reachability, rather than fighting Tailscale's
  own netfilter management.
- **Disable Tailscale's netfilter management**
  (`tailscale set --netfilter-mode=off`, or the equivalent flag) so
  `tailscaled` stops inserting `ts-input` ahead of ufw, letting ufw see
  and filter `tailscale0` traffic as originally intended. Would restore
  the model documented in `HOMELAB.md`, but may affect other Tailscale
  networking behavior (subnet routes, exit nodes, etc.) — not currently
  used here, but worth checking before flipping it.
