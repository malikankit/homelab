

## 2026-Aug-14

1. Setup SSH Key

ssh-keygen -t ed25519 -C "github@ankitmalik.in"

2. Install Clipboard and copy this file to clipboard

sudo apt install wl-clipboard

cat ~/.ssh/id_ed25519.pub | wl-copy
 

3. Git Clone homelab

cd ~/code/
git clone git@github.com:malikankit/homelab.git


4. Tailscale setup — Tailnet-only, key-only SSH (no Tailscale SSH, no passwords)

Installed openssh-server, restricted SSH to the Tailnet via ufw, hardened
sshd to key-only auth (no passwords/keyboard-interactive), confirmed
Tailscale SSH stays off, tested end-to-end from a tailnet peer. Full
steps, rationale, and execution log in tailscale_setup.md.

Scripts: ufw_rules.sh, sshd_hardening.sh, test_ssh_setup.sh.

Commit: 7a93dcd "Add Tailnet-only, key-only SSH setup docs and scripts"

5. Homelab-wide overview doc

Added ../HOMELAB.md at the repo root — the 3-machine topology (geekom/
geekom-linux, mba13/mba13-linux, mbp16/mbp16-mac), the AM vs. Zenith Tailscale trust
distinction (host-level hardening is the real security boundary, not
tailnet ACLs — matters because Zenith has a different admin and other
users), the SSH access map, and the SSH key inventory/convention.

6. Dedicated inter-host SSH key

Generated geekom-linux_to_tailnet_ed25519 — a key separate from the existing
GitHub key (id_ed25519, comment github@ankitmalik.in), specifically for
SSH between homelab machines on the AM tailnet. One key per trust
boundary, matching the pattern mbp16 already used (separate GitHub /
Zenith / inter-host keys). Both public keys copied into this folder
(geekom-linux_to_tailnet_ed25519.pub, id_ed25519.pub) for easy copy-paste into
other machines' authorized_keys.

Commit: 4ab8d01 "Add homelab overview doc and geekom's public keys"

7. Reviewed mba13-linux (mba13, Asahi Linux) and moved to per-machine ufw allowlists

mba13-linux already had SSH working, with a stricter ufw policy than geekom's
initial setup: port 22 allowed only from specific known peer IPs, not
"any device on the tailnet." Adopted the same policy on geekom — rewrote
ufw_rules.sh to allow SSH only from mba13-linux and mbp16-mac's specific
Tailscale IPs (scoped to the tailscale0 interface), retiring the old
tailnet-wide rule. Wrote mba13/ufw_rules.sh capturing mba13-linux's existing
rules plus the new geekom-linux entry.

Added the knowledge/ folder with knowledge/tailscale_udp_41641.md,
documenting why 41641/udp is opened (direct peer-to-peer connections,
unrelated to switching between AM and Zenith tailnets — a question that
came up when reviewing the rule).

Commit: 1474bfe "Move to per-machine ufw allowlists, add mba13 script,
document 41641/udp"

8. TODO.md and mba13-linux follow-up

Created ../TODO.md to track open follow-ups: updating ufw allowlists with
Zenith IPs once a machine reconnects to that network, investigating a
Tailscale DNS health warning seen on mba13-linux, and formalizing mba13-linux's sshd
hardening into a script (found two gaps vs. geekom's baseline:
AuthenticationMethods was `any` not `publickey`, PermitRootLogin was
`prohibit-password` not `no`).

Also updated the local `sham` alias in ~/.bashrc to SSH into mba13-linux by IP
instead of hostname, working around a MagicDNS short-hostname resolution
issue on geekom (not yet root-caused — tracked in TODO.md).

Commit: 445ffb9 "Add homelab TODO list, link it from HOMELAB.md"


## 2026-Aug-15

1. Claude Code session migration notes

Documented how to migrate dev folders + their Claude Code session history
from mba13-linux to geekom so `/resume` still works — sessions are keyed to a
project's absolute path and stored purely locally
(~/.claude/projects/<mangled-path>/), so the code folder and its matching
session directory have to move together to the same absolute path.
Written up in knowledge/claude_code_session_migration.md.

2. Hardened geekom for always-on remote access (Tailscale SSH from anywhere)

Checked current state: GNOME auto-suspend was already effectively off and
unattended-upgrades auto-reboot was already disabled, but neither was
enforced at a level that couldn't be casually undone. Wrote
disable_sleep.sh: masks the systemd sleep/suspend/hibernate targets
(authoritative — blocks suspend regardless of what triggers it), adds an
explicit logind.conf override, and locks the GNOME dconf settings.

Added SSH keepalive (ClientAliveInterval/ClientAliveCountMax) to the sshd
hardening drop-in, to survive flaky cafe wifi without leaving zombie
sessions.

Documented all of this, plus the bigger unresolved risk, in
always_on_setup.md: the root disk is LUKS-encrypted, so any reboot
(crash, power blip, update) leaves geekom with no network stack until
someone physically types the passphrase — sleep being handled doesn't
fix that. Laid out the options (TPM2 auto-unlock vs. dropbear-initramfs
vs. accepting the risk) without picking one; tracked as an open decision
in TODO.md, along with a manual BIOS check ("restore power after AC
loss").

Commit: 64be7bf "Harden geekom for always-on remote access, add
session-migration doc"

3. Ran disable_sleep.sh, hit a bug, hit a live GUI incident, fixed and verified both scripts

First run of disable_sleep.sh silently stopped after step 1 with no error,
twice. Root cause: `set -euo pipefail` plus `systemctl status` on an
already-masked (inactive) unit returns non-zero, which aborts the script
mid-pipe even though the `grep` after it would have succeeded. Fixed by
appending `|| true` to that status-check line.

Re-running the fixed script triggered a real incident: step 2's
`systemctl restart systemd-logind` knocked out the active GNOME graphical
session — after re-entering the password, the machine landed on a text
console instead of the desktop. Diagnosed live (via this same machine's
own shell, independent of the broken GUI session): `gdm.service` itself
never crashed, but the login greeter session had cycled and dropped to a
getty. Recovered via a VT switch / GDM restart; no reboot needed.

Confirmed after recovery that the script had in fact run to full
completion despite the incident — all three layers (masked sleep targets,
logind override, dconf lock) were present and identically timestamped.
Verified sleep-blocking directly: `sudo systemctl suspend` now fails with
"Access denied", which is systemd-logind refusing the call because
suspend.target is masked — the intended behavior, not a bug. One cosmetic
loose end noted but left alone: `sleep-inactive-battery-type` isn't
picking up its dconf lock, harmless since geekom (a mini PC) has no real
system battery to trigger that code path.

Also re-ran sshd_hardening.sh to apply the ClientAliveInterval/
ClientAliveCountMax keepalive added earlier — confirmed live in
/etc/ssh/sshd_config.d/00-tailnet-hardening.conf.

Added geekom/logs/ to persist script run output going forward
(disable_sleep_2026-08-15.log, sshd_hardening_2026-08-15.log).


## Before 2026-Aug-14








