

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


## 2026-Aug-16

1. Screenshot-server test harness + CDP/manual-tab capture (snapshot-tool repo)

Built `test_screenshot_server.html` — a standalone page (no dependency on
the rest of `crypto_cad_rates.html`) to iterate on `screenshot_server.py`
directly: resolve a ticker via CoinGecko's public search, POST to
`/screenshot`, and show the raw response/extracted price/screenshot/errors
without going through the full tool.

Diagnosed a Playwright error report as the classic two-step-install trap:
`pip install -r requirements.txt` installs the Python bindings but not the
actual browser binary — `playwright install chromium` is a separate,
required step.

Extended `screenshot_server.py` with a second browser mode, chosen via an
interactive startup prompt (or `SCREENSHOT_SERVER_MODE=fresh|cdp` to skip
it): the original sandboxed-Chromium launch, or attaching over CDP to an
already-running Chrome/Brave/etc. window (`--remote-debugging-port=9222`),
which carries real cookies/login/trust and is less likely to trip
Cloudflare's bot check. Added a matching third UI option in
`crypto_cad_rates.html`'s manual panel — "Copy URL, open it yourself &
capture" — that copies the dated CoinGecko URL, counts down (default 15s,
editable, or "Capture now"), then calls a new `/screenshot-manual` endpoint
that finds the matching tab by URL (no reliable "focused tab" signal exists
over CDP) and screenshots it directly. Initially gated that endpoint to
CDP-mode only, then realized the tab-search logic never actually depended on
CDP specifically — Playwright's own launched Chromium window is just as real
and queryable — so relaxed it to work in fresh mode too (paste into the
server's own already-open window instead of a separate browser). Added a
`/mode` endpoint the UI polls to show a live "paste into X window" hint.
Not yet committed in the snapshot-tool repo as of this writing.

Worked out the exact Brave launch command for CDP mode with a named profile
("CT"): `open -na "Brave Browser" --args --remote-debugging-port=9222
--profile-directory="CT"` — `-n` forces a new process so `--args` isn't
silently dropped, `--profile-directory` wants the folder name (not the
display name shown in Brave's UI, check `brave://version` if they differ),
and Brave has to be fully quit (Cmd+Q) first since the flag only applies on
a clean launch, not a window opened from an already-running process.

2. zsh setup on geekom itself

Installed Oh My Zsh + Powerlevel10k + zsh-autosuggestions +
zsh-syntax-highlighting + zsh-completions + fzf, all via direct git clones
(no sudo needed — zsh 5.9 was already present, already listed in
`/etc/shells`). Hand-wrote a fresh `~/.zshrc` (not the OMZ template) and
migrated the bash aliases (`sham`, `hl`, `hlg`, `cr`, plus the standard
`ll`/`la`/`l`/`grep --color` ones) into it. `chsh -s $(which zsh)` and
`p10k configure` both need an interactive terminal (password prompt / font
detection), so those were left for a real session rather than done headless
here — confirmed afterward that `~/.zshrc` now carries Powerlevel10k's
instant-prompt block, so both were completed.

Backed up `~/.zshrc` and `~/.p10k.zsh` to `zshrc_backup/` in this folder,
with `zsh_setup.md` documenting the full plugin list and exact
from-scratch reproduction steps for another machine.


## 2026-Aug-21

1. mba13-mac onboarding (outbound-only)

Generated mba13-mac's dedicated inter-host SSH key
(`mba13-mac_to_tailnet.pub`, not `_ed25519` suffixed like the others —
inconsistency noted, not fixed) and authorized it on geekom. Ran the new
`mba13/zsh_setup_mac.sh` there and confirmed outbound SSH from mba13-mac
to geekom works.

Decided mba13-mac is **outbound-only**: it should never be SSH'd into,
only used to SSH out. Confirmed via Tailscale's own "Disable incoming
connections" toggle (macOS app), which blocks all inbound tailnet
traffic to the device at the Tailscale layer. This removed the need for
macOS firewall/pf scripting, inbound sshd hardening, and adding
mba13-mac to other machines' ufw allowlists — trimmed
`mba13/todo_mba13-mac_onboard.md` and `HOMELAB.md`'s tables accordingly.
Verified the block is real: `nc -zv` and `ssh` from geekom to
mba13-mac's Tailscale IP (`100.71.170.17`, found via `tailscale status`)
both returned "Connection refused."

Commits: `a1d4010` "SSH Key for MBA13-Mac", `f73e87a` "Scope mba13-mac to
outbound-only, drop inbound hardening steps".

2. Tailnet hostname migration

Renamed all three Tailscale devices for clarity (physical name + OS):
`am6` → `geekom-linux`, `am-ma` → `mba13-linux`, `ams-mbp16` →
`mbp16-mac` — ahead of onboarding `mba13-mac`, which was already named
that way. Updated every reference across the repo (docs, scripts,
comments), renamed the inter-host SSH key files/comments to match
(keypairs themselves unchanged, so existing `authorized_keys` entries
stayed valid), and updated `ufw_rules.sh` on both `geekom/` and `mba13/`
— though the *live* ufw rules on each machine still need
`sudo ./ufw_rules.sh` re-run to pick up the renamed comments (tracked in
`TODO.md`, cosmetic only).

Commit: `93a65bf` "Migrate Tailnet hostnames to <physical>-<os>
convention".

3. `mbp16/zsh_setup_mac.sh` written

Same self-contained pattern as mba13's script (pulls
`geekom/zshrc_backup/.p10k.zsh` from the repo clone, writes its own
`.zshrc`) — written but not yet run on mbp16-mac itself.

Commit: `4db4532`.

4. Discovered Tailscale bypasses ufw

While testing whether geekom's ufw allowlist would block an SSH attempt
from mba13-mac (whose IP wasn't in the allowlist), found that it
didn't — the connection succeeded anyway. Root cause: `tailscaled`
inserts its own `ts-input` iptables chain **ahead of every ufw chain**
in `INPUT`, and that chain blanket-accepts traffic arriving over
`tailscale0` before ufw's rules ever run. Confirmed via
`sudo iptables -L INPUT/-L ts-input -n -v --line-numbers`.

This means the ufw per-machine allowlist documented in `HOMELAB.md` as
the real security boundary isn't actually doing that job for Tailscale
traffic, on AM or Zenith. Real reachability today is: Tailscale network
membership (solid) + Tailscale ACL policy (default: allow-all between
tailnet devices, unless a custom policy has been written) + sshd
key-only auth (still real and working). Wrote this up in
`knowledge/tailscale_ufw_bypass.md`, linked it from `HOMELAB.md`'s trust
model section, and left the actual fix (write restrictive Tailscale
ACLs, vs. `tailscale set --netfilter-mode=off` to let ufw see the
traffic again) as an open, undecided `TODO.md` item.

Commit: `3bdac17`.

5. zsh prompt overhaul

Tried two approaches to visually flag "you're on geekom" in a
terminal: (a) enabling Powerlevel10k's built-in `context` segment
(`user@hostname`, suppressed by default), and (b) an OSC 11
escape-sequence trick to recolor the terminal background on SSH
sessions specifically (gated on `$SSH_CONNECTION`, restored via OSC 111
on exit). (b) didn't render in iTerm2 despite being a standards-based
escape sequence most terminals support.

Simplified instead: disabled Powerlevel10k entirely
(`ZSH_THEME=""`, instant-prompt block commented out, left installed and
easy to re-enable) in favor of zsh's native
`PROMPT='%n@%m:%~$ '` — a plain bash-style prompt
(`am@geekom-linux:~$`) with no Nerd Font or terminal-escape-sequence
dependency, so it renders identically everywhere. Kept the SSH
background-color hook (still useful, just not the primary signal
anymore) and changed its color from an initial dark red to Solarized
Light's `base3` (`#fdf6e3`) per explicit request. Also fixed geekom's
live `~/.zshrc`, which had drifted from the repo copy (a manual edit had
half-commented the background-color block, leaving an orphaned `trap`
line active).

Commits: `70f3dcc`, `4bc3754`, `13bb27d`.

6. Added `gitandansiblesetupplan.md`

Handoff doc from a Claude Desktop planning session — a two-phase plan to
self-host services starting with a Forgejo git server + Obsidian sync on
geekom (Phase 1), with Ansible-based reproducibility deferred to Phase 2.
Execution of Phase 1's git-server piece starts next.

Commit: `7022f21`.


## Before 2026-Aug-14








