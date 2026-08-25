

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

## Before 2026-Aug-14








