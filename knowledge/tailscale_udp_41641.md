# Why `41641/udp` is open in ufw

Referenced from `geekom/ufw_rules.sh` and `mba13/ufw_rules.sh`.

## What it is

`41641/udp` is Tailscale's **data-plane** port — `tailscaled`'s
WireGuard-based tunnel port, used for the actual encrypted traffic between
peers (SSH, or anything else routed over the tailnet). It is unrelated to
authentication/login.

## Why it's opened inbound, from "Anywhere" (not scoped to `tailscale0`)

Tailscale prefers **direct peer-to-peer connections** between two nodes
over UDP hole-punching. When that fails (strict NAT, firewalls on both
ends, etc.), it falls back to relaying all traffic through a Tailscale
**DERP relay server** — which still works, but adds latency and caps
throughput at the relay's capacity.

Opening `41641/udp` inbound on the host firewall is Tailscale's own
documented recommendation for improving the odds of a direct connection
instead of falling back to relay. It can't be scoped to the `tailscale0`
interface, because before a direct connection is established there *is no*
`tailscale0` path to that peer yet — the handshake has to arrive on a
"normal" interface first.

## Why it's *not* related to switching tailnets (AM ↔ Zenith)

This came up because it was unclear in hindsight whether this rule was
added to support switching `mba13-linux` between the AM and Zenith tailnets
remotely. It isn't, and doesn't need to be:

- Switching networks (`tailscale switch`, or logging out of one tailnet
  and into another) is a **control-plane** operation — it talks to
  Tailscale's coordination server over outbound HTTPS (443). Outbound
  traffic is already allowed by default (`ufw default allow outgoing`),
  regardless of any inbound UDP rule.
- `41641/udp` only affects the **data plane** (how existing tunnel traffic
  routes — direct vs. relayed), not login/auth/network-switching.

So this rule can be reasoned about purely as a connection-quality
optimization, independent of anything tailnet-identity-related.

## Is it safe to leave open to "Anywhere"?

Yes — `tailscaled` authenticates peers at the WireGuard/Noise-protocol
layer regardless of network path, so an unauthenticated packet arriving on
this port from the open internet can't do anything; it just won't
complete a handshake. This is the standard, documented Tailscale posture,
not a homelab-specific risk tradeoff.

## How to verify it's doing its job

On the machine in question:
```
sudo ss -ulnp | grep tailscaled   # confirms tailscaled is bound to 41641
tailscale ping <peer>             # reports "direct" vs relay in the reply
```
If `tailscaled` is actually bound to a different (e.g. random) UDP port,
this rule isn't the one doing the work and may be a stale leftover worth
revisiting.
