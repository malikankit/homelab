# geekom (geekom-linux): always-on SSH dev machine (+ future web server)

geekom's role: an always-on home server, reachable over Tailscale SSH from
anywhere (e.g. working from a cafe), and later hosting some services
(TBD). This doc covers what "always reachable" actually requires — sleep
is only part of it.

## What was already true before touching anything

Checked before making changes:
- `sleep-inactive-ac-type` (GNOME) was already `'nothing'` — desktop
  auto-suspend wasn't actually enabled.
- `logind.conf` had no idle-suspend override — systemd's default
  (`IdleAction=ignore`) was already in effect.
- `unattended-upgrades` `Automatic-Reboot` was already `false` — no
  surprise 2am reboots from routine security updates.
- `tailscaled` was already enabled at boot (`systemctl is-enabled
  tailscaled` → `enabled`) — it reconnects on its own after any reboot,
  no manual step needed *once the OS is actually up*.

So the desktop-level "will it go to sleep" risk was already low. What
wasn't in place was a **bulletproof, systemd-level** guarantee, and there
was an entirely separate, more serious risk (see below).

## Layer 1: sleep/suspend — hardened via `disable_sleep.sh`

`disable_sleep.sh` makes "never sleeps" authoritative rather than
incidental, in three layers (most to least fundamental):

1. **`systemctl mask sleep.target suspend.target hibernate.target
   hybrid-sleep.target`** — blocks suspend/hibernate at the systemd level
   regardless of what tries to trigger it (GNOME settings, logind, an
   ACPI button event, someone running `systemctl suspend` by accident).
   This is the layer that actually matters; the rest is defense in depth
   / keeping the Settings UI honest.
2. **`/etc/systemd/logind.conf.d/00-no-idle-suspend.conf`**:
   `IdleAction=ignore`, stated explicitly rather than left as an implicit
   default.
3. **System-wide dconf override + lock**
   (`/etc/dconf/db/local.d/00-no-sleep` +
   `/etc/dconf/db/local.d/locks/00-no-sleep`): pins
   `sleep-inactive-ac-type` / `sleep-inactive-battery-type` to `'nothing'`
   and locks them so they can't be casually changed via Settings.

Run: `sudo ./disable_sleep.sh` (idempotent).

**Caution if running this over a local GUI session:** step 2
(`systemctl restart systemd-logind`) can knock out an *active local*
GNOME session — logind restarting drops the running login session, and
you can land on a text console (tty/getty) instead of the desktop until
you switch VTs or restart `gdm`. This happened once during initial setup;
recoverable (VT switch, `sudo systemctl restart gdm`, or physical reboot
as a last resort — no data risk from the script itself), but avoid running
this script from the physical console when possible, or expect a
momentary GUI hiccup and know how to recover if you do.

Verifying it worked: `sudo systemctl suspend` should fail with
`Access denied` — that's logind refusing the call because `suspend.target`
is masked, which is the intended result, not an error.

## Layer 2: SSH keepalive — `ClientAliveInterval`/`ClientAliveCountMax`

Added to the sshd hardening drop-in (`sshd_hardening.sh` →
`/etc/ssh/sshd_config.d/00-tailnet-hardening.conf`): server sends a null
packet every 60s and drops the session after 3 missed responses. This
matters specifically for the cafe-wifi use case — it keeps NAT/firewall
mappings alive on flaky connections and proactively reaps dead sessions
instead of leaving zombies.

Client-side complement (set this in `~/.ssh/config` on whichever laptop
connects *from* the cafe, not on geekom):
```
Host geekom-linux
    ServerAliveInterval 60
    ServerAliveCountMax 3
```

## Layer 3 (unresolved, bigger than sleep): LUKS full-disk encryption blocks remote reboot recovery

**This is the real risk to "always reachable."** `lsblk` shows the root
disk is LUKS-encrypted:
```
nvme0n1p3 crypto_LUKS → dm_crypt-0 (LVM) → ubuntu--vg-ubuntu--lv (/)
```
On *any* reboot — a crash, a power blip, a manual kernel update — geekom
will sit at a passphrase prompt with **no network stack at all**. Tailscale
can't even start, let alone SSH. Nothing here is reachable remotely until
someone is physically present to type the passphrase. This can strand you
mid-trip regardless of how well sleep is handled.

Options, not yet decided:

1. **TPM2 auto-unlock** (`systemd-cryptenroll --tpm2-device=auto`) —
   the machine unlocks itself automatically at boot (measured-boot bound
   to the TPM, no human/network needed), fully solving the reachability
   problem. Tradeoff: loses "still encrypted if physically stolen while
   powered off" protection (an attacker with physical access and an
   unmodified boot chain can just power it on). For a home server that
   isn't likely to be physically stolen, this tradeoff is probably
   reasonable — but it's a real security posture change, not a free
   convenience win, so worth deciding deliberately rather than defaulting
   into it.
2. **`dropbear-initramfs`** — a minimal SSH server in the initramfs lets
   you SSH in and type the LUKS passphrase remotely, before the main OS
   boots. Important limitation: this only gets basic LAN networking
   (static IP or DHCP) — **not** Tailscale, since `tailscaled` isn't
   running yet at that boot stage. So it doesn't actually solve
   "unlock from a cafe" unless something else on the same LAN can relay
   (e.g. another always-on Tailscale-connected device that SSHes into
   dropbear's LAN address on your behalf) — meaningfully more
   infrastructure, not a quick fix.
3. **Do nothing, accept the risk** — keep `Automatic-Reboot false` (already
   the case), minimize other reboot triggers, and accept that an outage
   or crash means walking over to type a passphrase before geekom is
   reachable again. Reasonable if reboots are already rare and a physical
   visit within a day or so is acceptable.

Tracked as an open decision in `../TODO.md`.

## Other things worth checking (not yet done)

- **BIOS/UEFI: "restore power after AC loss."** If there's a real power
  outage, does geekom auto-boot when power returns, or stay off until a
  physical button press? This is a firmware setting, can't be checked or
  changed from software — worth confirming in the BIOS directly.
- **Future services (web server, etc.)**: when that happens, expose new
  ports the same way SSH is already exposed — a per-machine IP allowlist
  on `tailscale0` via `ufw_rules.sh`, not "open to the tailnet" or, worse,
  "open to the LAN/internet." See `HOMELAB.md` for the policy rationale.
