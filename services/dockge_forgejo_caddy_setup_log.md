# Dockge / Forgejo / Caddy setup log

Everything done to bring up Phase 1 of `gitandansiblesetupplan.md`
(self-hosted git server on geekom) — every file created or edited, its
full content, why it's shaped that way, every command run, and every
manual step that still needs (or needed) you directly.

**Note (2026-Sep-02):** this was originally written as a same-day
snapshot on 2026-Aug-25, mid-setup. Several things it described as
pending were completed later that same day — see the corrections
inline below, and `geekom/early_journal.md`'s 2026-Aug-25 entry for the
full narrative (install completed, `tailscale serve` run,
`START_SSH_SERVER` bug found/fixed, Dockge later put in charge of
managing both stacks, service map added). Kept as-is otherwise since
the file-by-file reasoning is still accurate.

Convention used throughout: **compose files are git-tracked (this
repo), runtime state is not** — it lives on the host under
`~/services/state/<app>/`, kept out of git entirely so data/secrets
never land in the repo. This is documented in each service's own
`README.md` and in the (now-simplified) `services/.gitignore`.

---

## 1. Docker Engine + Compose (prerequisite, done 2026-08-22)

Installed via the official Docker apt repo (not the convenience
script), matching how other packages are installed elsewhere in this
repo:

```bash
# add Docker's apt repo + GPG key, then:
sudo apt install docker-ce docker-ce-cli containerd.io \
  docker-compose-plugin docker-buildx-plugin docker-ce-rootless-extras
sudo usermod -aG docker am
```

Verified with `docker run hello-world`. `am` in the `docker` group
means compose commands don't need `sudo`. No file in this repo records
the exact apt-repo-add commands — this was run directly, not scripted,
since it's a one-time host bootstrap step covered by
`geekom/early_journal.md`'s 2026-Aug-22 entry.

**Manual step required**: none beyond the sudo password at install
time — already done.

---

## 2. `services/dockge/docker-compose.yml` (created, then edited)

Full current content:

```yaml
services:
  dockge:
    image: louislam/dockge:1
    container_name: dockge
    restart: unless-stopped
    ports:
      - "127.0.0.1:5001:5001"   # admin UI — localhost only, see README
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
      - /home/am/services/state/dockge/data:/app/data
      - /home/am/services/state/dockge/stacks:/opt/stacks
    environment:
      - DOCKGE_STACKS_DIR=/opt/stacks
```

**Why this shape:**
- `127.0.0.1:5001:5001` — Dockge has full Docker-socket access
  (`/var/run/docker.sock` mounted in), which is equivalent to root on
  the host. Treated as a local-admin-only tool, not something to expose
  over Tailscale even though the tailnet is otherwise trusted — reached
  via SSH tunnel (`ssh -L 5001:localhost:5001 am@100.78.110.5`) or
  geekom's own desktop browser instead.
- Host volume paths are **absolute** (`/home/am/services/state/dockge/...`),
  not relative (`./data`) — first draft used relative paths, then was
  rewritten once the "state lives outside the repo" convention was
  decided, so runtime data isn't accidentally created inside the git
  working tree.
- `DOCKGE_STACKS_DIR=/opt/stacks` — so any stack Dockge itself manages
  (including Forgejo/Caddy, if you choose to manage them through its UI
  later instead of the CLI) is written to `~/services/state/dockge/stacks/`
  on the host, same outside-the-repo convention.

**Commands run:**
```bash
mkdir -p ~/services/state/dockge/{data,stacks}
docker compose -f ~/code/homelab/services/dockge/docker-compose.yml up -d
```

**Status**: deployed, container `dockge` up and healthy. Admin account
creation is a manual step — **you still need to do this** (visit
`http://localhost:5001` or via the SSH tunnel above, first visit
prompts account creation). Not confirmed done in this session — please
verify/do it if you haven't.

**Commits**: `4bf1eb8` (added), `b6912c5` (moved state paths out of
repo).

---

## 3. `services/dockge/README.md` (created)

Full content:

```markdown
# Dockge

Compose-native container management UI for geekom — no lock-in, stacks
are plain `docker-compose.yml` files.

The compose definition here is git-tracked (this repo); its runtime
state lives outside the repo, under `~/services/state/dockge/`, so
data/secrets never end up in git.

## Access

Bound to `127.0.0.1:5001` only — **not** exposed over Tailscale. Dockge
has full Docker-socket access (equivalent to root on this machine), so
it's treated as a local-only admin tool rather than a tailnet-reachable
service. Reach it either:

- Directly on geekom's own desktop, browse to `http://localhost:5001`
- Remotely via an SSH tunnel:
  `ssh -L 5001:localhost:5001 am@100.78.110.5` then browse to
  `http://localhost:5001` on your own machine

## Setup

\`\`\`bash
mkdir -p ~/services/state/dockge/{data,stacks}
docker compose -f ~/code/homelab/services/dockge/docker-compose.yml up -d
\`\`\`

First visit to `http://localhost:5001` prompts you to create the admin
account.

## Data / backup

- `~/services/state/dockge/data/` — Dockge's own app data (accounts,
  settings)
- `~/services/state/dockge/stacks/` — every compose stack Dockge
  manages (including this homelab's Forgejo/Caddy stacks, once deployed
  through it) lives here as plain files, not a database — back up by
  copying this directory.

## Port

`5001` (UI), localhost-only per above.
```

**Why**: documents access method (two ways in, since it's
localhost-only by design), setup command, and what's in the state
directory for backup purposes — matches the doc convention used for
every other service in this repo.

---

## 4. `services/forgejo/docker-compose.yml` (created this session)

Full content:

```yaml
services:
  forgejo:
    image: codeberg.org/forgejo/forgejo:10
    container_name: forgejo
    restart: unless-stopped
    environment:
      - USER_UID=1000
      - USER_GID=1000
      - FORGEJO__server__DOMAIN=6l.seahorse-enigmatic.ts.net
      - FORGEJO__server__ROOT_URL=https://6l.seahorse-enigmatic.ts.net/
      - FORGEJO__server__SSH_DOMAIN=6l.seahorse-enigmatic.ts.net
      - FORGEJO__server__SSH_PORT=2222
      - FORGEJO__server__START_SSH_SERVER=false
      - FORGEJO__service__DISABLE_REGISTRATION=true
    volumes:
      - /home/am/services/state/forgejo/data:/data
      - /etc/timezone:/etc/timezone:ro
      - /etc/localtime:/etc/localtime:ro
    ports:
      - "127.0.0.1:3000:3000"     # web UI — Caddy fronts this, see ../caddy
      - "100.78.110.5:2222:22"    # git-over-SSH — bound to geekom's own
                                   # Tailscale IP, reachable by any AM-tailnet
                                   # device (see ../../HOMELAB.md re: the
                                   # Tailscale/ufw bypass — this is the same
                                   # exposure model as everything else today)
```

**Why this shape, field by field:**
- `image: codeberg.org/forgejo/forgejo:10` — pulled and confirmed
  working (`10.0.3+gitea-1.22.0`). Forgejo publishes from
  `codeberg.org`, not Docker Hub. Pinned to major version `10`, not
  `:latest`, so upgrades are a deliberate tag bump later, not silent.
- `USER_UID=1000` / `USER_GID=1000` — matches your actual `am` user
  (`id am` → `uid=1000(am) gid=1000(am)`), so files Forgejo writes into
  the bind-mounted `/data` are owned by you on the host, not root or a
  mismatched UID.
- `FORGEJO__server__DOMAIN` / `ROOT_URL` / `SSH_DOMAIN` — pre-filled
  with `6l.seahorse-enigmatic.ts.net`, this tailnet's MagicDNS/cert
  domain for geekom, so Forgejo generates correct links/clone URLs
  without you having to type them into the install wizard by hand.
  `ROOT_URL` uses `https://` since the whole point is reaching this
  through `tailscale serve`'s HTTPS termination.
- `SSH_PORT=2222` — advertised port for clone URLs (see the `ports:`
  section) — 2222, not 22, so it doesn't collide with geekom's own
  OS-level sshd on port 22. `START_SSH_SERVER=false` (corrected from
  `true`, see the note below) — this image runs a real `sshd`
  permanently via its own `s6` supervisor regardless of this setting
  (the actual git-over-SSH mechanism, via `AuthorizedKeysCommand`
  calling `gitea serv`); leaving Forgejo's *own* built-in Go SSH server
  also enabled made both try to bind the container's port 22 at once.
  Found and fixed same-day (2026-Aug-25) after a crash loop — see
  `services/forgejo/README.md`'s "Known gotcha" section and
  `geekom/early_journal.md`'s item 8/11 that day. Commit: `aa2fde2`.
- `DISABLE_REGISTRATION=true` — locks out public self-registration from
  the start; only an admin-created account (created via the install
  wizard's first-run flow, which is separate from this setting) will
  exist. Matches the plan's "disable public registration" step.
- Two `ports:` entries, each bound to a **specific IP**, not `0.0.0.0`:
  - `127.0.0.1:3000:3000` — web UI, host-loopback only. Caddy (below)
    is the only thing meant to reach it.
  - `100.78.110.5:2222:22` — git-over-SSH, bound to geekom's own
    Tailscale IP specifically (not loopback, not all-interfaces) — so
    it's reachable by any device on the AM tailnet (for `git clone`/
    `push`), but not from geekom's LAN interface or the public
    internet. This was an explicit design decision (see the plan file)
    accepting the same exposure model already in place for every other
    tailnet-reachable service on this network today — see
    `HOMELAB.md`'s Tailscale/ufw-bypass note for why ufw doesn't add a
    second gate here; the real gate is Forgejo's own per-user SSH key
    auth.
- `/etc/timezone` and `/etc/localtime` mounted read-only — so log
  timestamps inside the container match geekom's actual local time,
  standard practice for this image.

**Commands run:**
```bash
mkdir -p ~/services/state/forgejo/data
docker pull codeberg.org/forgejo/forgejo:10        # verified the tag exists first
docker compose -f ~/code/homelab/services/forgejo/docker-compose.yml up -d
```

**Verification done:**
```bash
docker ps --filter name=forgejo
# → Up, ports 127.0.0.1:3000->3000/tcp, 100.78.110.5:2222->22/tcp
curl -o /dev/null -w "%{http_code}\n" http://localhost:3000/   # → 200
docker logs forgejo --tail 20
# → confirmed: SSH host keys generated, "Prepare to run install page",
#   AppURL(ROOT_URL) = https://6l.seahorse-enigmatic.ts.net/
```

**Status**: deployed, install wizard reachable locally on
`127.0.0.1:3000` (confirmed with `curl`, returns HTTP 200 — the install
page). **Not yet completed by you**: the install wizard itself
(creating the admin account) — this is a manual step, not yet done as
of this writing.

**Commit**: `954cbde`.

---

## 5. `services/forgejo/README.md` (created this session)

Full content:

```markdown
# Forgejo

Self-hosted git server (Forgejo, a Gitea fork) for geekom — Phase 1 of
`gitandansiblesetupplan.md`. Replaces GitHub for repos that don't need to
be public (starting with an Obsidian vault repo, via `obsidian-git`).

Runtime state (`~/services/state/forgejo/data/` — repos, DB, config,
SSH host keys) lives outside this repo entirely, same convention as
Dockge.

## Access

- **Web UI**: bound to `127.0.0.1:3000` only. Not directly reachable
  over Tailscale — `../caddy` reverse-proxies it and `tailscale serve`
  terminates TLS, so the real entry point is
  `https://6l.seahorse-enigmatic.ts.net/` once that's wired up.
- **git-over-SSH**: port `2222`, bound to geekom's own Tailscale IP
  (`100.78.110.5`), so any AM-tailnet device can reach it directly
  (same exposure model as the rest of this tailnet today — see
  `HOMELAB.md`'s Tailscale/ufw-bypass note). Gate is Forgejo's own
  per-user SSH key auth, not ufw.
  Clone example: `git clone ssh://git@100.78.110.5:2222/<user>/<repo>.git`

## Setup

\`\`\`bash
mkdir -p ~/services/state/forgejo/data
docker compose -f ~/code/homelab/services/forgejo/docker-compose.yml up -d
\`\`\`

First visit to `http://localhost:3000` (or via an SSH tunnel from
another machine: `ssh -L 3000:localhost:3000 am@100.78.110.5`) runs the
install wizard — defaults to SQLite (fine for this scale), the
`DOMAIN`/`ROOT_URL`/`SSH_DOMAIN`/`SSH_PORT` fields are already
pre-filled from the compose file's environment. Create the admin
account there. `DISABLE_REGISTRATION=true` is already set, so no one
else can self-register afterward — new users are admin-created only.

## Data / backup

`~/services/state/forgejo/data/` — everything (SQLite DB, repos, SSH
host keys, avatars, config). Back up by copying this directory
(stop the container first for a consistent SQLite snapshot).

## Ports

`3000` (web UI, localhost-only), `2222` (git-over-SSH, Tailscale-IP-only).
```

**Why**: same doc convention as Dockge's README — access paths, setup
command, backup notes, ports. Flags that SQLite is the assumed database
choice in the install wizard (never explicitly forced via env vars —
you'll see and confirm this in the wizard itself).

**Commit**: `954cbde` (same commit as the compose file).

---

## 6. `services/caddy/Caddyfile` (created this session)

Full content:

```
:8080 {
	bind 127.0.0.1
	reverse_proxy 127.0.0.1:3000
}
```

**Why this shape:**
- Listens on port `8080`, explicitly bound to `127.0.0.1` — even though
  the container runs with host networking (see below), this `bind`
  directive is what actually keeps it unreachable from the LAN; without
  it, host networking would expose port 8080 on every interface geekom
  has, not just loopback.
- `reverse_proxy 127.0.0.1:3000` — forwards to Forgejo's published web
  port. Works because of host networking (see next file) — the Caddy
  container shares geekom's network namespace, so `127.0.0.1:3000`
  inside the container is the same `127.0.0.1:3000` Forgejo is bound to
  on the host.
- No TLS directives — deliberately plain HTTP. TLS termination is
  `tailscale serve`'s job (it already has the tailnet's HTTPS cert),
  not Caddy's, in this design.

---

## 7. `services/caddy/docker-compose.yml` (created this session)

Full content:

```yaml
services:
  caddy:
    image: caddy:2
    container_name: caddy
    restart: unless-stopped
    # Host networking so the Caddyfile can reach Forgejo at its published
    # 127.0.0.1:3000 without needing a shared docker network with the
    # forgejo compose stack. Caddyfile explicitly binds to 127.0.0.1, so
    # this doesn't expose anything on the LAN despite host networking.
    network_mode: host
    volumes:
      - ./Caddyfile:/etc/caddy/Caddyfile:ro
      - /home/am/services/state/caddy/data:/data
      - /home/am/services/state/caddy/config:/config
```

**Why this shape:**
- `image: caddy:2` — official image, major-version pinned (not
  `:latest`), same rationale as Forgejo's tag choice.
- `network_mode: host` — Forgejo and Caddy are two **separate** compose
  projects (no `docker-compose.yml` combines them), each gets its own
  isolated docker network by default (`forgejo_default`,
  `caddy_default` if it weren't host-networked). Rather than wiring a
  shared external docker network between two independently-managed
  stacks, host networking lets Caddy just reach `127.0.0.1:3000`
  directly, since that's where Forgejo already publishes to on the
  host itself. Trade-off: host networking means Caddy *shares* geekom's
  real network namespace — mitigated by the `Caddyfile`'s explicit
  `bind 127.0.0.1`, so nothing is actually exposed beyond loopback.
- `./Caddyfile:/etc/caddy/Caddyfile:ro` — mounted read-only from the
  repo (relative path, resolved relative to this compose file's own
  directory by `docker compose`, not your shell's cwd) — config has no
  secrets in it, so it stays git-tracked directly rather than living
  under `~/services/state/`.
- `/data` and `/config` — Caddy's own state dirs (its default paths for
  TLS storage / autosaved config), pointed at
  `~/services/state/caddy/{data,config}/` for the outside-the-repo
  convention, even though in this design Caddy issues no certs of its
  own (TLS is `tailscale serve`'s job) so these stay mostly empty.

**Commands run:**
```bash
mkdir -p ~/services/state/caddy/{data,config}
docker compose -f ~/code/homelab/services/caddy/docker-compose.yml up -d
```

**Verification done:**
```bash
docker ps --filter name=caddy               # → Up
curl -o /dev/null -w "%{http_code}\n" http://127.0.0.1:8080/   # → 200
docker logs caddy --tail 15
# → confirmed: config loaded from /etc/caddy/Caddyfile, server running
#   on 127.0.0.1:8080, no errors
```

The `200` from `curl http://127.0.0.1:8080/` confirms the full local
chain works: Caddy → Forgejo, before touching Tailscale at all.

**Commit**: `dcd76c7`.

---

## 8. `services/caddy/README.md` (created this session)

Full content:

```markdown
# Caddy

Reverse proxy sitting between `tailscale serve` and Forgejo. Only reason
it's here rather than pointing `tailscale serve` straight at Forgejo's
port: this is the intended place to add path-based routing once more
services join the tailnet-exposed side of this stack (per
`gitandansiblesetupplan.md`'s Phase 2) — for now it's a thin pass-through
to `../forgejo`.

## How it's wired

- Runs with `network_mode: host` so its Caddyfile can reach Forgejo at
  `127.0.0.1:3000` directly, no shared docker network needed.
- Caddyfile binds explicitly to `127.0.0.1:8080` — despite host
  networking, this keeps it unreachable from the LAN; only
  `tailscale serve` (running on the host, also loopback-only by
  default) fronts it.
- `tailscale serve https / http://127.0.0.1:8080` terminates TLS using
  this tailnet's HTTPS Certificates feature
  (`6l.seahorse-enigmatic.ts.net`) and forwards to Caddy, which forwards
  to Forgejo. No port is opened on any real network interface at any
  layer — `tailscale serve` handles routing entirely within
  `tailscaled`.

## Setup

\`\`\`bash
mkdir -p ~/services/state/caddy/{data,config}
docker compose -f ~/code/homelab/services/caddy/docker-compose.yml up -d

# One-time, needs sudo:
sudo tailscale serve https / http://127.0.0.1:8080
\`\`\`

Verify from another tailnet device (not geekom itself):
`https://6l.seahorse-enigmatic.ts.net/` should load Forgejo's UI with a
valid cert (no browser warning).

## Data

`~/services/state/caddy/{data,config}/` — Caddy's own state (TLS
internal storage, autosave config). Caddy issues no certs of its own
here (TLS is handled by `tailscale serve`), so this is mostly empty;
kept for parity with the rest of this repo's state-outside-git
convention.

## Port

`8080`, localhost-only (`tailscale serve` is the only thing that should
ever reach it).
```

**Why**: explains *why* Caddy exists at all in this chain (future
path-based routing, not needed today), the exposure chain end-to-end,
and the one remaining manual command.

**Commit**: `dcd76c7` (same commit as the compose file and Caddyfile).

---

## 9. Manual steps — status (as originally written, 2026-Aug-25 mid-setup)

| Step | Needs | Status at the time this was written |
|---|---|---|
| `sudo tailscale serve https / http://127.0.0.1:8080` | Interactive sudo password on geekom | Not yet done — non-interactive sudo was tried and refused. |
| Visit `https://6l.seahorse-enigmatic.ts.net/` from another tailnet device, confirm cert is valid | Any other AM-tailnet device + browser | Not yet done — depended on the step above. |
| Complete Forgejo's install wizard (creates the admin account) | Browser | Reachable (`curl` → 200), account-creation not yet confirmed. |
| Dockge admin account creation | Browser | Deployed, account-creation status unknown at the time. |
| Create the Obsidian-vault repo in Forgejo | Depends on admin account existing | Not started. |
| `git clone ssh://git@100.78.110.5:2222/<user>/<repo>.git` verification | A repo to clone | Not started. |

**All of the above were completed later the same day (2026-Aug-25).**
Per `geekom/early_journal.md`'s entries for that date: `tailscale serve
--bg http://127.0.0.1:8080` was run (CLI syntax had changed from the
form above), Forgejo's install wizard was completed (after diagnosing
and fixing the `START_SSH_SERVER` crash loop noted above), two Obsidian
vault repos (`obs`, `llmwiki`) were created and synced via
`obsidian-git` from both Macs, and this `homelab` repo itself was
mirrored to Forgejo too.

## 10. Follow-up status (as of 2026-Sep-02)

- `HOMELAB.md` — updated separately as this work landed (SSH key
  inventory, machine table); not re-verified line-by-line against this
  log as part of this note.
- `geekom/early_journal.md` — now has a full entry for this Forgejo/
  Caddy work (2026-Aug-25, items 2 and 6–11), including the deployment,
  the `START_SSH_SERVER` bug, Dockge managing both stacks, and the
  service map.
- obsidian-git client-side plugin configuration — done; see
  `obsidian_sync_setup.md`.
