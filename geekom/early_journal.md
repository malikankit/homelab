

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


## 2026-Aug-22

1. Installed Docker Engine + Compose plugin

Installed via the official Docker apt repo (not the convenience script,
to match how other packages are installed elsewhere in this repo):
`docker-ce`, `docker-ce-cli`, `containerd.io`, `docker-compose-plugin`,
`docker-buildx-plugin`, `docker-ce-rootless-extras`. Added `am` to the
`docker` group (`sudo usermod -aG docker am`) so compose commands don't
need `sudo`. Confirmed working with `docker run hello-world`. This
unblocks Phase 1 of `gitandansiblesetupplan.md` (Dockge, Forgejo,
Caddy).

2. Decided where self-hosted service state lives, using FHS as a guide

Discussed Linux's FHS (Filesystem Hierarchy Standard — `/etc` config,
`/var` runtime state, `/opt` third-party software, `/srv` served data)
as background, then decided against keeping any service's runtime
data/config inside this git repo. Landed on `~/services/{state,configs}/
<app>/` on the host, kept entirely separate from the repo's
`services/<app>/{docker-compose.yml,README.md}` (the reproducible,
git-tracked part). Compose files reference the host paths directly via
`docker compose -f <path-in-repo> up -d` — no symlink between the repo
and `~/services/`.


## 2026-Aug-23

1. Dockge compose stack written, then its state path corrected

Wrote `services/dockge/docker-compose.yml` + README (admin UI bound to
`127.0.0.1:5001` only). First draft used relative `./data`/`./stacks`
volume paths; per the FHS-informed decision above, rewrote them to
absolute host paths (`/home/am/services/state/dockge/{data,stacks}`)
and created those directories. Rewrote `.gitignore` — first to ignore
the (now-removed) in-repo data dirs, then simplified to just an
explanatory comment once state moved out of the repo entirely, since
there's normally nothing under `services/` left to ignore.

Commits: `4bf1eb8` "Add Dockge compose stack (Step 3 of Forgejo setup
plan)", `b6912c5` "Move Dockge runtime state out of the repo, into
~/services". Not yet deployed (`docker compose up -d` not run) as of
this writing.

2. Unexplained SSH access loss — diagnosed as a power-loss reboot

Lost SSH access to geekom and had to reboot it manually to regain
access. Investigated afterward via `journalctl --list-boots` and
`journalctl -b -1`: the previous boot's log stream stops abruptly
mid-stream (last lines are routine `tailscaled`/`kernel` noise at
19:40:09) with no `Reached target Shutdown`, `Power Off`, or `reboot:
Restarting system` message — the signature of an actual power loss, not
a clean shutdown or reboot. Ruled out unattended-upgrades
(`Automatic-Reboot` was already confirmed off), and nothing in this
session's own command history around that time issued a restart. Next
boot didn't start until 2026-08-24 14:51 EDT, meaning geekom was down
for several hours before being noticed and power-cycled by hand. The
real fix (BIOS "Restore on AC Power Loss", so the machine powers back on
by itself after an outage instead of needing a physical button press)
remains an open, unverified `TODO.md` item — not a UPS, per explicit
decision (not worth it for this machine).


## 2026-Aug-24

1. Shared dotfiles/aliases.sh + SSH tmux auto-attach

Created `dotfiles/aliases.sh` — a single shared, POSIX-safe alias file
sourced from every machine's `.zshrc` (`ll`, `la`, `l`, `grep --color`,
`alert`, `hl`, `hlg`, `cr`), with `dotfiles/README.md` documenting the
convention and why aliases belong in `.zshrc`/`.bashrc` (sourced on
every interactive shell) rather than `.zprofile`/`.profile`
(login-shell-only). Added an SSH-triggered tmux auto-attach block to
`.zshrc`: `exec tmux new-session -A -s main` when `$SSH_CONNECTION` is
set and not already inside tmux — `exec` avoids a leftover outer shell
process. Found and fixed live drift in geekom's actual `~/.zshrc` (a
hand-edited `cr` alias not reflected in the repo copy) while wiring
this in.

Commit: `1760006`.

2. Migrated dotfile management to chezmoi

Repeated manual-copy drift bugs (an orphaned `trap` line previously, the
`cr` alias just above) motivated moving off the plain-copy
`zshrc_backup/` approach entirely. Chose [chezmoi](https://www.chezmoi.io/),
with its source directory living inside this homelab repo
(`chezmoi/`, not a separate dotfiles repo) — chezmoi shells out to git,
which auto-detects the parent repo, so this works with no extra
plumbing. Installed chezmoi to `~/.local/bin` (no sudo), pointed it at
the repo via `~/.config/chezmoi/chezmoi.toml` (not git-tracked — the one
per-machine bootstrap file), and brought `.zshrc`, `.p10k.zsh`,
`.gitconfig` under management (`chezmoi add`). Retired
`geekom/zshrc_backup/` (`git rm -r`) and updated every reference to it
(`mba13/zsh_setup_mac.sh`, `mbp16/zsh_setup_mac.sh`,
`geekom/zsh_setup.md`) — left `early_journal.md`'s own historical
mentions of it untouched, since this is an append-only log of what was
true at the time. Found and fixed a follow-up bug: chezmoi initially
tried to deploy `chezmoi/README.md` itself into `~/README.md` (every
file in the source dir is a managed target by default) — fixed with
`chezmoi/.chezmoiignore`.

Commits: `6705985` "Manage dotfiles with chezmoi instead of manual
copy-and-sync", `ad79856` "Add .chezmoiignore so chezmoi doesn't try to
deploy chezmoi/README.md".

3. Extended chezmoi to mba13-mac and mbp16-mac; templated per-machine aliases

Converted `dot_zshrc` to `dot_zshrc.tmpl`, since `.zshrc` isn't identical
across machines (each has its own SSH-shortcut aliases). The template
branches on a `machine` value read from that host's own
`chezmoi.toml` `[data]` section — deliberately not chezmoi's built-in
`.chezmoi.hostname`, so an OS-level or Tailscale rename doesn't silently
flip which alias block a machine gets. Rewrote both `mba13/
zsh_setup_mac.sh` and `mbp16/zsh_setup_mac.sh`: they still install Oh My
Zsh/plugins/fzf as before, but now also install chezmoi and `chezmoi
apply` instead of hand-writing `.zshrc` via heredoc. Verified on geekom
itself first (`chezmoi diff` showed only the intended comment/logic
change, no unintended drift) before writing the Mac scripts. Not yet run
on mba13-mac or mbp16-mac as of this writing — needs `git pull` +
`./<machine>/zsh_setup_mac.sh` on each.

Commit: `b8ced76` "Extend chezmoi bootstrap to mba13-mac and mbp16-mac".

4. Per-connection tmux sessions instead of one shared "main"

The SSH auto-attach added earlier always joined a single `main` tmux
session, so a second SSH window collided with the first (same
scrollback, resizing one affected the other). Changed it to
`tmux new-session -A -s "ssh-$$"` — each SSH connection gets its own
uniquely named session (`$$` = that shell's PID), while `-A` still
reattaches cleanly if the same connection's shell is re-entered.

Commit: `83d90c1`.

5. Discovered the tailnet's devices were renamed, and that HTTPS Certificates is now enabled

Found (via `tailscale status`) that all four homelab devices now show
short Tailscale device names — `6l` (geekom-linux), `13l` (mba13-linux),
`13m` (mba13-mac), `16m` (mbp16-mac) — not previously recorded in this
repo. Also confirmed `tailscale cert` no longer reports "HTTPS cert
support is not enabled" (the blocker noted in the still-pending Forgejo/
Caddy plan) — the tailnet's MagicDNS/cert domain is
`seahorse-enigmatic.ts.net`, e.g. geekom is reachable at
`6l.seahorse-enigmatic.ts.net`. Recorded both in `HOMELAB.md`'s machine
table. This removes the one manual prerequisite blocking the Caddy +
`tailscale serve` TLS step of the Forgejo setup plan.

6. Forgejo/Dockge status check

As of this writing: Docker Engine + Compose are installed and `am` is in
the `docker` group (since 2026-Aug-22 above); `services/dockge/
docker-compose.yml` exists and its state dirs are created, but the
container has never been started (`docker compose up -d` not yet run);
`services/forgejo/` and `services/caddy/` don't exist yet — Forgejo and
Caddy haven't been started at all. Next concrete step is deploying
Dockge.

## 2026-Aug-25

1. tmux: shared session with one window per SSH login, instead of one
   session per login

The per-connection sessions (`ssh-<pid>`) added the day before avoided
the old shared-`main` scrollback collision, but scattered work across
many disposable sessions with no single place to see them all. Changed
the SSH auto-attach block in `dot_zshrc.tmpl`: a new SSH login now opens
a new *window* inside one shared `main` session (`tmux new-window -t
main \; attach-session -t main`) if `main` already exists, or creates
`main` fresh if not — tmux lets different clients attached to the same
session look at different windows independently, so this doesn't
reintroduce the collision `main` originally had. Verified via `chezmoi
diff`, applied, committed.

Commit: `b06b9f8`.

Also scoped out a related idea — using Karabiner's Caps Lock (now
remapped to a held ⌘⌃⌥⇧ chord on the Macs) as a second tmux prefix
alongside Ctrl+b — and logged it in `TODO.md` rather than building it,
since it needs Karabiner/terminal-passthrough details not yet in hand.
Commit: `c958b81`.

2. Forgejo and Caddy deployed — Phase 1 of `gitandansiblesetupplan.md`
   substantially done

Wrote and deployed `services/forgejo/docker-compose.yml` (image
`codeberg.org/forgejo/forgejo:10`, confirmed `10.0.3+gitea-1.22.0`):
web UI on `127.0.0.1:3000` only, git-over-SSH on port `2222` bound
directly to geekom's own Tailscale IP (`100.78.110.5`) rather than
loopback — any AM-tailnet device can reach it, gate is Forgejo's own
per-user SSH key auth, same exposure model already in place for
everything else on this tailnet (see `HOMELAB.md`'s Tailscale/ufw-bypass
note). `DOMAIN`/`ROOT_URL`/`SSH_DOMAIN` pre-filled to
`6l.seahorse-enigmatic.ts.net`; `DISABLE_REGISTRATION=true` set from the
start. Verified locally (`curl` → 200, logs show SSH host keys
generated and the install page ready). Commit: `954cbde`.

Wrote and deployed `services/caddy/{docker-compose.yml,Caddyfile}`:
runs with `network_mode: host` so it can reach Forgejo at
`127.0.0.1:3000` without a shared docker network between the two
independent compose projects, but the Caddyfile explicitly binds to
`127.0.0.1:8080` so host networking doesn't actually expose anything on
the LAN. Reverse-proxies plain HTTP to Forgejo — no TLS in Caddy itself,
since that's `tailscale serve`'s job. Verified the full local chain
(`curl http://127.0.0.1:8080/` → 200, i.e. Caddy → Forgejo working)
before touching Tailscale at all. Commit: `dcd76c7`.

Wrote a full file-by-file setup log
(`services/dockge_forgejo_caddy_setup_log.md`, not committed — kept as
a working doc) covering every file's exact content and the reasoning
behind each setting, for review before going further.

**Still open, needs the user directly** (interactive sudo, can't be
scripted from here): `sudo tailscale serve https / http://127.0.0.1:8080`
on geekom, to actually expose Forgejo over Tailscale HTTPS at
`https://6l.seahorse-enigmatic.ts.net/`. Until that runs, Forgejo is
only reachable locally on geekom. Also still pending: confirm Dockge's
and Forgejo's admin accounts actually got created (containers are up,
but account-creation status isn't confirmed), create the Obsidian-vault
repo in Forgejo, verify `git clone ssh://git@100.78.110.5:2222/...` from
a peer machine, then update `HOMELAB.md`.

3. Markdown preview added to vim

No `.vimrc` existed before this. Installed vim-plug (single-file plugin
manager, no external deps) to `~/.vim/autoload/plug.vim`, and added
`chezmoi/dot_vimrc` declaring `previm` + `open-browser.vim` for
Markdown live preview (`:PrevimOpen` — opens in the default browser,
auto-refreshes on save). Chose previm over
Node-based alternatives (e.g. `markdown-preview.nvim`) because geekom
has no Node/npm installed but does have `python3`, which previm's
preview server can use directly. Installed the plugins
(`vim -es -u ~/.vimrc -c "PlugInstall --sync" -c "qa"`), confirmed both
landed in `~/.vim/plugged/`. `.vimrc` is now chezmoi-tracked alongside
`.zshrc`/`.p10k.zsh`/`.gitconfig`; vim-plug itself stays unmanaged
(external tool, same convention as Oh My Zsh), with its install command
documented in `chezmoi/README.md`. Commit: `b706d2e`.

4. `sshme` alias added to all 4 machines; fixed a stale key filename

Added a host-less `sshme` alias per machine — `ssh -i <that machine's
own tailnet identity key>`, so you append the target yourself
(`sshme am@<ip>`) — to `dot_zshrc.tmpl`'s per-machine branches. Added a
branch for `mba13-linux` (previously absent from this template) just
for this alias, since it has its own tailnet key
(`mba13-linux_to_tailnet_ed25519`) but wasn't otherwise templated.
While doing this, found and fixed a stale reference: the existing
`sham` alias pointed at `~/.ssh/am6_to_tailnet_ed25519`, the pre-rename
filename from before the 2026-08-22 hostname migration — the real file
on disk is `geekom-linux_to_tailnet_ed25519`; the alias was missed when
everything else was renamed. Verified via `chezmoi diff`/`apply`
(confirmed the diff touched only geekom's `sham`/`sshme` lines).
Commit: `d26b260`.

5. Reconciled a stale SSH access-map entry; started tracking geekom's `authorized_keys` via chezmoi

While fixing a stale comment in geekom's `~/.ssh/authorized_keys`
(still read the pre-rename `am-ma-tailnet@...`), found that
mba13-linux's outbound key was already live there — contradicting
`HOMELAB.md`'s access map, which listed that path as "not yet"
authorized. Confirmed intentional; updated the access map and added
the key's missing row to the key inventory table instead of removing
it. Also brought geekom's `authorized_keys` under chezmoi management
(`private_dot_ssh/private_authorized_keys`, preserving `700`/`600`
perms) — deliberately geekom-only for now, since the file differs per
host; tracked extending it to mba13-linux/mbp16-mac in `TODO.md`.
Commit: `3ea0dfd`.

6. Merged the two Mac setup scripts into one shared `basic_setup.sh`

`mba13/zsh_setup_mac.sh` and `mbp16/zsh_setup_mac.sh` were
near-identical, differing only in the `machine = "..."` line — every
new setup step had to be hand-copied into both and could silently
drift (almost did, when vim-plug bootstrapping landed in mbp16's copy
first). Replaced both with `basic_setup.sh` at the repo root: detects
which machine it's running on from the hostname, then walks through
each section (Oh My Zsh, zsh plugins, fzf, chezmoi, vim-plug) one at a
time, explaining what it's about to do and asking for confirmation —
so declining a section now and rerunning later just picks up the rest.
Every section keeps the original idempotency checks. Commit: `3a0178a`.

Two bugs found and fixed shortly after, both from real runs on mbp16-mac:

- **`chezmoi apply` tried to overwrite mbp16's `authorized_keys` with
  geekom's.** The file (item 5 above) had no machine guard. Fixed via
  `.chezmoiignore` (which chezmoi processes as a template automatically,
  no `.tmpl` suffix needed): ignores `.ssh/authorized_keys` whenever
  `machine != geekom-linux`. Verified by temporarily overriding
  `chezmoi.toml`'s `machine` value locally. Commit: `a4999a9`.
- **`raw.githubusercontent.com` is blocked on mbp16's ISP**, breaking
  the vim-plug `curl` download (and, it turned out, Oh My Zsh's
  installer script too — same domain). Switched both to `git clone`
  from `github.com` instead: Oh My Zsh clones straight into
  `~/.oh-my-zsh`; vim-plug clones to a scratch dir and copies out the
  one file it needs. Commits: `89749fb`, `4d18de4` (doc update to match).

7. Diagnosed a `sshme -L` tunnel typo and a Brave-specific DNS gotcha

Two separate mbp16-side issues this session, neither a bug in this
repo: (a) a Dockge SSH tunnel (`sshme -L 5001:localhost:50001 am@6l`)
had a typo in the remote port (`50001` vs Dockge's actual `5001`),
confirmed by checking nothing was listening on `50001` on geekom; (b)
after `sudo tailscale serve --bg http://127.0.0.1:8080` was run
(Tailscale's CLI syntax changed since the plan was written — the old
`tailscale serve https / http://...` form is gone), `6l.seahorse-
enigmatic.ts.net` worked fine via `curl`/`scutil --dns` on mbp16 but
failed in Brave specifically with `DNS_PROBE_POSSIBLE` — Brave's
built-in Secure DNS (DoH) bypasses the OS resolver entirely, so it
never saw Tailscale's MagicDNS answer. Confirmed working in Firefox
instead. No repo changes for either — both diagnosed and left as
client-side notes.

8. Forgejo's built-in SSH server conflicted with the image's real `sshd`

After submitting Forgejo's install wizard, the container crash-looped
on every subsequent start: `bind: address already in use` on `:22`.
Root cause, found by inspecting the image directly (`docker run
--entrypoint sh ... find / -iname '*openssh*'`): this Forgejo image
runs a **real `sshd`** permanently via its own `s6` supervisor
(unconditional — the intended git-over-SSH mechanism, via
`AuthorizedKeysCommand` calling `gitea serv`), and
`FORGEJO__server__START_SSH_SERVER=true` (set when the compose file was
first written) made Forgejo's own built-in Go SSH server also try to
bind the same port. Fixed by setting it to explicit `false` — omitting
the var wasn't enough, since `environment-to-ini` only overrides keys
it's actually given and won't unset a value already baked into
`app.ini` from a prior boot. Verified stable (`HTTP 200` locally and
through the full `tailscale serve → caddy` chain) after recreating the
container. Commit: `aa2fde2`.

9. Let Dockge manage Caddy and Forgejo through its own UI

Dockge showed `caddy`/`forgejo` as running but "not managed" — it can
see any container via its `docker.sock` access, but only offers
start/stop/restart from its UI for stacks whose compose file lives
under its own `DOCKGE_STACKS_DIR`. Rather than duplicating those
compose files, mounted `~/code/homelab/services` into the Dockge
container read-only at the identical host path, then symlinked
`stacks/caddy` and `stacks/forgejo` back into the repo (created via
`docker exec dockge ln -s ...`, since the host-side stacks dir is
root-owned). Read-only mount is deliberate — compose-file edits still
only happen via git, avoiding two sources of truth. Commit: `525c27b`.

10. Service map diagram, and making its upkeep durable

Built `geekom/service_map.html` — a diagram (HTML + inline SVG) of the
Docker services on geekom, their ports, and how each is reached
(`tailscale serve → caddy → forgejo` web UI, direct git-SSH on `:2222`
bypassing Caddy, Dockge's isolated local/tunnel-only access with its
`docker.sock` control-plane link). Published as a Claude Artifact, then
saved into the repo since it's meant to stay current, not a one-time
snapshot. Commit: `7304a3c`. Added `CLAUDE.md` at the repo root
documenting that this diagram should be updated in the same batch of
work as any service change — the file's own comment header wasn't
durable enough on its own (only surfaces if `service_map.html` happens
to get opened), so this makes it visible any time this repo is worked
in. Commit: `eb6c0c4`.

11. Forgejo install completed; debugged a crash loop from the install wizard's own self-restart

Submitted Forgejo's install wizard; it got stuck loading. `docker logs`
showed the install itself completing fine ("First-time run install
finished!"), but Forgejo's own post-install self-restart then
crash-looped on `bind: address already in use` for `:22` every ~60s.
Traced it to the image's *own* real `sshd`, run permanently via `s6`
(inspected the image directly with `docker run --entrypoint sh ...`) —
`FORGEJO__server__START_SSH_SERVER=true` in the compose file (set when
first written) made Forgejo's built-in Go SSH server also try to bind
the same port. Fixed by setting it to explicit `false` (omitting it
wasn't enough — `environment-to-ini` won't unset a value already baked
into `app.ini` from a prior boot). Verified stable afterward. Commit:
`aa2fde2`; full write-up in `services/forgejo/README.md`'s "Known
gotcha" section.

Caught the whole rest of the day's documentation up in the same pass:
`geekom/early_journal.md` itself (this entry, retroactively for items
5–10 above), `gitandansiblesetupplan.md`'s checklist, `services/caddy/
README.md` (the `tailscale serve` CLI syntax change, and a Brave
Secure-DNS gotcha diagnosed separately — see item 7), and
`HOMELAB.md`'s changelog. Commit: `bff45cf`.

12. A `High priority` section added to `TODO.md`

Split out the concrete Forgejo/obsidian-git next steps plus the three
existing open items with real availability/security stakes (LUKS
remote-unlock, BIOS power-loss recovery, Tailscale/ufw bypass) above
the undifferentiated `Open` list, so what actually matters next doesn't
get lost in the longer-tail items. Commit: `b6c5a00`.

13. tmux reverted back to one independent session per SSH connection

The shared-`main`-session-plus-new-window design from item 1 (this same
date) turned out broken once actually tested with two simultaneous SSH
logins: tmux gives every client attached to the *same* session one
shared "current window," so one connection switching windows dragged
every other connection's view along with it — the exact collision that
design was meant to avoid. Reverted `dot_zshrc.tmpl` back to the
original per-connection `ssh-<pid>` session design (what item 1 had
replaced). tmux session *groups* (`new-session -t main -s ssh-$$`)
could give independent per-connection views while still sharing one
window pool, if wanted later — noted as an option, not implemented.
Commit: `60ad504` (bundled with two small TODO additions: a `scpme`
alias mirroring `sshme`, and a rclone OneDrive download to review once
finished — see items 14–15).

14. rclone configured on geekom, reusing mbp16-mac's existing OneDrive auth

Installed rclone via its official install script (`v1.75.0` — Ubuntu's
own apt package was a stale `1.60.1`). Rather than re-running OneDrive's
OAuth flow on geekom, copied mbp16-mac's already-authenticated
`~/.config/rclone/rclone.conf` over directly (`scp`, using mbp16-mac's
own outbound `sshg` alias — geekom can't pull from mbp16-mac, nothing
is authorized in that direction), moved it into place on geekom with
`700`/`600` permissions, and confirmed it authenticates
(`rclone lsd OneDrive:` listed real folders with no re-auth prompt).
Started a real download (`Arq Backup Data/<...>` →
`~/onedrive_downloads/`) in the user's own separate tmux session, so it
isn't tied to this one — tracked in `TODO.md` to review for completeness
once finished.

15. Two Obsidian vaults synced through Forgejo via `obsidian-git`

Created `obs` (the actual vault, continuous manual edits) and `llmwiki`
(a separate repo for an LLM-generated wiki — the plan doc's
"Karpathy-style automated wiki pipeline", not yet built; kept separate
per the plan doc's own stated rationale: different commit cadence/
access pattern) as private, empty repos on Forgejo. Set up
`obsidian-git` on both mba13-mac and mbp16-mac, each with its own
dedicated SSH key (`<machine>_to_forgejo_ed25519` — same
one-key-per-trust-boundary convention as every other inter-host key in
this repo) and a `Host forgejo` alias in `~/.ssh/config`. Full runbook
in the new `obsidian_sync_setup.md`. Cross-device sync-loop testing
(edit on one device → auto-commit → push → pull on the other) not yet
separately confirmed. Commit: `9fd59fd`.

16. This `homelab` repo now mirrors to Forgejo too, on every push

Same per-machine dedicated-key pattern applied to geekom itself
(`geekom-linux_to_forgejo_ed25519`) plus a `homelab` repo created on
Forgejo the same way as `obs`/`llmwiki`. Rather than a second named
remote (which would need an explicit second `git push` command every
time), added a **second push URL to `origin`** instead — `git fetch`/
`pull` stay GitHub-only, but a plain `git push` now pushes to both
GitHub and Forgejo in one command. Verified with a real push (GitHub:
already up to date; Forgejo: received full history as a new `main`
branch). Documented in `HOMELAB.md` alongside the rest of the SSH key
inventory. Commit: `f65ceb9`.

## 2026-Aug-26

1. Small alias/skill additions

Added `shix` (a muscle-memory duplicate of `sshg`, same target) and
`sshdockge` (`ssh -N -L 5001:localhost:5001 ...` — forwards geekom's
Dockge UI to `localhost:5001` in one command, instead of typing the
full tunnel out by hand each time) to both Macs' alias blocks. Fixed a
portability bug in `basic_setup.sh`: `${name,,}` (lowercase expansion)
needs bash 4+, but macOS ships bash 3.2 by default — swapped in a
`tr`-based lowercase instead. Also firmed up the LiveSync+CouchDB idea
into a real `TODO.md` entry (later re-confirmed/kept as one clean entry
when revisited on 2026-Aug-28 below). Added a `quick-commit` skill
(`.claude/skills/quick-commit/SKILL.md`) for fast commit+push in this
repo without the full review ceremony, given how low-stakes/personal
it is. Commits: `2dccb96`, `dd05828`, `b9369d4`.

## 2026-Aug-28

1. sshfs mount of geekom's `~/code` on both Macs

Added a `mountg`/`umountg` alias pair to both `mba13-mac` and
`mbp16-mac` blocks — `mountg` mounts geekom's `~/code` at `~/6l/code`
via `sshfs`, using each machine's own dedicated key, with
`reconnect`/keepalive options for laptop sleep and network changes.
`basic_setup.sh` got a new `sshfs` section (macFUSE + `sshfs-mac` via
Homebrew, idempotent) — macFUSE needs a one-time manual approval in
System Settings plus a reboot before it actually works, which the
section calls out explicitly rather than letting `mountg` fail silently
later. Commit: `1712f28`.

2. Found and fixed a live misconfiguration: geekom identifying as `mba13-mac`

While reviewing the mount-alias diff, noticed geekom's own
`~/.config/chezmoi/chezmoi.toml` had `machine = "mba13-mac"` instead of
`"geekom-linux"` — meaning geekom's live `.zshrc` had been rendering
mba13-mac's aliases (missing `sham`, `sshme`/`sshg`/`sshl` all pointing
at a key that doesn't exist on geekom) instead of its own. Cause:
`basic_setup.sh` was accidentally run on geekom itself at some point,
and its "which machine is this?" prompt got answered with the wrong
name. Not a security issue (the misdirected aliases would just fail
with "no such file"), but a real functional bug — fixed by correcting
`chezmoi.toml` and re-applying; confirmed `sham`/`sshme` restored
correctly. `chezmoi.toml` is local/untracked, so no commit for the fix
itself, but worth recording here since it explains a few days of a
broken `sham` alias on geekom.

3. Stopped publishing the service map as a Claude Artifact

Noticed the earlier `geekom/service_map.html` Artifact publish had
started a live watch/subscription in the session (background
notifications on republish/comments) — explicitly didn't want that.
Unwatched it, and updated both `geekom/service_map.html`'s own header
comment and `CLAUDE.md` to say local-only going forward: view by
opening the file directly, don't publish diagrams/docs from this repo
as Artifacts unless asked. Saved as a standing memory too, not just an
in-repo note. Commit: `1712f28` (bundled with the mount-alias work
above).

4. tmux session hell: cleaned up 19 accumulated sessions, capped future growth

The per-connection-session design (`ssh-<pid>`, one independent tmux
session per SSH login) had no upper bound — a few days of logins left
19 sessions running on geekom. Cleaned up: kept `main`, `rclone`, and 4
sessions with a live `claude` process actively running in them (real
work in progress, not safe to kill), killed the 12 sessions sitting
idle at a bare `zsh` prompt. Fixed the underlying design: once 3+
sessions already exist, a new SSH login now joins `main` instead of
spawning another — below that threshold, still gets its own
independent session as before. Commit: `8eeaf28`.

5. `tmux.conf` added to chezmoi, `detach-on-destroy off`

First `tmux.conf` tracked in this repo (`chezmoi/dot_tmux.conf`). Sets
`detach-on-destroy off`, so a client attached to a session that gets
killed (or whose last window closes) lands on another existing session
instead of being kicked out to the outer shell — relevant given the
session-cap logic above, so a client doesn't get unceremoniously
dropped if its session is ever cleaned up while still attached.
Applied via `chezmoi apply` and reloaded live with
`tmux source-file ~/.tmux.conf`; confirmed with `tmux show-options -g
detach-on-destroy`.

## 2026-Aug-28 (continued)

6. `dojo-dl` tool added; OneDrive rclone download completed

Added `tools/dojo-dl/`: downloads the Vimeo video embedded in a
dojo-trading.com weekly market-update article using a real logged-in
session (Playwright `login.py` saves `session.json`, gitignored;
`download.py` replays it headlessly and shells out to `yt-dlp`) — first
step toward a transcription pipeline. Commit: `4de0bad`.

The OneDrive `rclone` download started on 2026-Aug-26 (item 14 above)
finished: 373.446 GiB / 373.446 GiB (100%), ~1d13h runtime, a few
transient errors (malformed drive id, chunk timeout, one JWT parse
error) that self-resolved on retry. Verified against disk (353,622
files, 375G matching the log) and marked complete in `TODO.md`.
Commits: `4de0bad` (log file), `019936d` (TODO.md).

7. sshfs/mountg troubleshooting, then switched macFUSE → FUSE-T

Live-tested `mountg` on an Apple Silicon Mac and hit three real
problems in sequence, each fixed:

- sshfs only forwards a known subset of `-o` keys to the underlying
  `ssh` process — `ServerAliveInterval`/`ServerAliveCountInterval`
  aren't on that list, so they leaked through to the FUSE mount helper
  and got rejected (`fuse: unknown option(s)`). Fixed by wrapping them
  in `ssh_command="ssh -o ServerAliveInterval=15 -o
  ServerAliveCountInterval=3"` instead. Commit: `67db5d5`.
- macFUSE's System Settings "Allow" step doesn't even appear on Apple
  Silicon until Reduced Security is enabled via Recovery Mode's Startup
  Security Utility first — documented this gap in `basic_setup.sh`'s
  comments. Commit: `4ba2275`.
- Editing *macOS's* specific boot-volume-group policy through Recovery
  didn't work out in practice on a machine dual-booting Asahi Linux, so
  switched `basic_setup.sh`'s sshfs section from macFUSE to **FUSE-T**
  entirely — implements FUSE via a Network Extension instead of a
  kernel extension, so it only needs a plain System Settings approval,
  no Recovery Mode. Commit: `c8d704f`.
- Verified live on mba13-mac afterward: bare sshfs (IdentityFile only,
  no `ssh_command`) mounts fine after a one-time local-network
  permission prompt; the `ssh_command` workaround from the first fix
  above actually broke FUSE-T's sshfs — SSH auth succeeded but no
  `sftp-server` subprocess ever spawned (confirmed from geekom's own
  sshd logs). Dropped the keepalive-tuning wrapper, kept `reconnect`;
  documented the local-network permission prompt too. Commit: `9b10587`.

8. `basic_setup.sh` hands off to a fresh `zsh` at the end

`mountg` appeared "missing" mid-session simply because the shell
testing it hadn't reloaded after `basic_setup.sh` ran — the script's own
process can't change the invoking shell's already-loaded environment.
Fixed by `exec`-ing a fresh `zsh` at the very end, in the same terminal
window; exiting it returns to whatever shell the script was run from.
Commit: `2538b4a`.

## 2026-Aug-30

1. `TODO.md` reorganized; mba13-mac onboarding marked complete

Confirmed the Obsidian sync-loop test (edit on one device → auto-commit
→ push → pull on the other) actually works end-to-end — checked off in
`TODO.md`. Demoted four items (LiveSync+CouchDB, LUKS remote-unlock,
BIOS power-loss, Tailscale/ufw bypass) from "High priority" to a
renamed "Low priority" section, and deduped two sets of entries that
had accumulated. Commit: `ea3962f`.

Filled mba13-mac's real AM-tailnet IP (`100.71.170.17`) into
`HOMELAB.md`'s machine table, and flipped its inbound-blocked /
Tailscale-SSH-off hardening status from "TBD" to confirmed-done.
Checked off in `TODO.md` and `mba13/todo_mba13-mac_onboard.md` — the
mba13-mac onboarding tracked since 2026-Aug-21 is now complete. Commit:
`b990c9f`.

## 2026-Aug-31

1. `hindi_translation` tool: Hinglish transcription via Trelis/tara

Added `tools/hindi_translation/hinglish_transcribe.py <audio_file>
[override_model_path] [--mode {mixedcode,hindi}]` — transcribes
Hindi/Hinglish audio via the Trelis/tara Whisper model (2B params,
BF16 safetensors), auto-chunking audio into ≤30s segments per the
model's limit and stitching the transcript back together. Defaults to
mixed-code (Hinglish) output. Default model path `~/models/tara`; if
missing, prompts for permission, shows a disk-space-vs-estimated-size
percentage, prompts again, then clones via `git+SSH`
(`git@hf.co:Trelis/tara`) reusing the SSH access already set up for
Hugging Face. Verified `--help`/error paths; not yet tested against a
real download/inference run (no GPU/model on geekom at the time).
Commit: `6170f77`.

## 2026-Sep-01

1. Aliases added directly on GitHub (bypassed this repo's usual flow)

A commit titled "Add aliases" (`70aba46`) landed on `dotfiles/aliases.sh`
pushed straight to GitHub, outside a Claude Code session — added
`shix`/`sham`/`shag`/`obsidian`-style aliases. Left an unclosed
`brave-debug()` function (fixed the next day, see 2026-Sep-02 item 3
below).

## 2026-Sep-02

1. `hinglish_transcribe.py` extended: `--minutes`, `--profile`, file
   output, interactive prompts, default `~/transcripts/` output dir

Several small additions to the Hinglish transcription tool from
2026-Aug-31, same session:

- `--minutes` caps how much of the file gets transcribed (fractional
  minutes allowed), passed through to `librosa.load`'s `duration=` so
  decoding stops early rather than loading the whole file first —
  useful for a quick test on a long file. Also added test-audio
  extensions (`*.mp3`/`*.wav`/`*.m4a`/`*.flac`) to `.gitignore` after
  catching a stray `clip.mp3` about to get committed. Commit: `03bcd6f`.
- `--profile` adds a background CPU/RAM sampler (`psutil`, every 0.5s)
  plus GPU memory (`nvidia-smi` if present, else
  `torch.cuda.memory_allocated()`) and per-chunk timing, active only
  during the actual transcription loop — reports seconds-of-processing
  per minute of audio, a real inference-speed rate rather than
  wall-clock-including-setup. Commit: `524580c`.
- `-o`/`--output` writes the transcript to a file (still printed to
  stdout too); `--profile-output` does the same for the profile report.
  New `prompt_for_missing_args()`: in an interactive terminal with any
  of `--minutes`/`--output`/`--profile`/`--profile-output` left unset,
  asks for each instead of silently defaulting — flags already given
  are used as-is, piped/scripted runs skip prompting entirely. Audio-file
  existence is checked before prompting. Commit: `44120bd`.
- Default output files to `~/transcripts/` (`<audio-stem>.txt` /
  `<audio-stem>.profile.txt`) via a new `prompt_output_path()` helper —
  asks whether to write a file at all, then offers that default path or
  a custom one. `~/transcripts/` is created automatically on write.
  Commit: `086013f`.

2. Merged the direct-to-GitHub "Add aliases" commit, fixed the syntax
   error it left, logged a cleanup TODO

Merged `70aba46` (2026-Sep-01, pushed outside a session) into this
session's branch (`b8744f4`). Its unclosed `brave-debug()` function was
a real syntax error that would break shell startup on every machine,
since `dotfiles/aliases.sh` is sourced directly from the repo checkout
— no `chezmoi apply` needed for it to take effect. Fixed with the
missing closing brace, verified with `bash -n`/`zsh -n`. Commit:
`7e05e01`. Left further cleanup for later — some of the newly added
aliases likely belong in `dot_zshrc.tmpl`'s per-machine blocks instead
of this shared file, and `ll`/`la`/`l`/`alert` appear to have been
accidentally removed — logged as a `TODO.md` item rather than fixed
inline. Commit: `6c577a1`.

3. Karabiner configs added for mba13/mbp16; mba13's UK keyboard
   documented

Added `karabiner/caps_lock_to_hyper.json` (shared across both Macs —
remaps Caps Lock to a Hyper key: Left Shift held with
Command+Control+Option, the standard workaround since Karabiner's `to`
event needs a `key_code` to attach modifiers to) and
`mba13/karabiner/uk_to_us_keyboard.json` — a trimmed, 3-manipulator
version of a Karabiner-store "UK→US Mac" rule, with the original's
first two manipulators (a Shift+3/Option+3 `#`/`£` swap) removed since
mba13's specific keyboard already produces `#` on Shift+3 without any
remapping. `basic_setup.sh` got a new Karabiner section that stages the
right file(s) into
`~/.config/karabiner/assets/complex_modifications/` per detected
machine and prints the paths — enabling a rule in the Karabiner-Elements
UI stays a manual step.

Also confirmed and documented mba13's exact keyboard: model
`MLY33ZS/A` (MacBook Air 13" M2 2022, `ZS/A` = India region code),
built-in keyboard reporting `is_built_in_keyboard: true`,
`transport: FIFO`, no `vendor_id`/`product_id` (Apple Silicon internal
keyboards aren't on the USB bus) — confirming `device_if`'s
`is_built_in_keyboard: true` identifier, not the `vendor_id`
checks, is what actually matches this device. Physical layout is
almost certainly British/ISO English (India-region default, matches
the extra ISO key/`§`±` key/Shift+3→`#` behavior observed directly);
`ioreg -c AppleHIDKeyboard | grep -i keyboardtype` returned no output
when tried, so the numeric `AppleKeyboardType` ID itself is still
unconfirmed. All written up in `mba13/karabiner/README.md` and
`karabiner/README.md`. Commit: `23189fb`.

## Before 2026-Aug-14








