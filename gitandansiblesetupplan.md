# Homelab Setup Plan
> Summary of planning decisions for handoff to Claude Code and the homelab repo.
> Generated: August 2026

---

## Context & Hardware

Two machines in play:

**Zenith** (primary workstation / inference machine)
- RTX 5070 GPU, ~11.6GB usable VRAM, GDDR7 ~672 GB/s bandwidth
- Primary role: local LLM inference (Qwen3-14B, DeepSeek-R1-Distill-14B via Ollama)
- 13B–14B models fit cleanly at Q4 quantization (~40–65 tok/s)

**Geekom A6** (homelab server — always-on)
- Ryzen 7 6800H, 16GB RAM (single-stick/single-channel — upgrade candidate), 1TB NVMe
- Primary role: self-hosted services, accessible via Tailscale
- Note: single-channel RAM limits CPU inference bandwidth (~25–40 GB/s effective); adding a second stick would enable dual-channel

Both machines connected via **Tailscale** for private, zero-config networking. No port forwarding, no public internet exposure.

---

## Overarching Goals

- Replace SaaS bills with self-hosted alternatives
- Full data privacy and local control
- Git-backed everything: configs, notes, wiki, service definitions
- Reproducible infrastructure (Ansible, eventually)
- All services accessible via Tailscale from any device

---

## Phase 1 — Critical This Week: Git + Obsidian Sync

### Goal
Get Forgejo running on the A6, accessible over Tailscale, with:
1. Obsidian vault syncing via `obsidian-git` plugin
2. A self-hosted wiki (backing the LLM wiki project and homelab docs)

### Stack

| Component | Tool | Notes |
|---|---|---|
| Git server | **Forgejo** | Active Gitea fork, more maintained |
| Reverse proxy | **Caddy** | Auto TLS via Tailscale, simple config |
| Obsidian sync | **obsidian-git plugin** | Scheduled commit/push/pull |
| Container mgmt | **Dockge** | Compose-native, no lock-in |

### Forgejo on A6 — Docker Compose

```yaml
services:
  forgejo:
    image: codeberg.org/forgejo/forgejo:latest
    container_name: forgejo
    environment:
      - USER_UID=1000
      - USER_GID=1000
    volumes:
      - ./forgejo-data:/data
    ports:
      - "127.0.0.1:3000:3000"   # HTTP — bound to localhost only
      - "127.0.0.1:2222:22"     # SSH git
    restart: unless-stopped
```

Expose via Tailscale — either:
- Direct Tailscale IP: `http://100.x.y.z:3000`
- Or via Caddy + Tailscale serve for HTTPS: `https://forgejo.your-tailnet.ts.net`

### Caddyfile (minimal)

```caddyfile
forgejo.your-tailnet.ts.net {
    reverse_proxy localhost:3000
}
```

Caddy handles TLS automatically via Tailscale's cert infrastructure.

### Obsidian Git Setup

1. Install **obsidian-git** community plugin in Obsidian
2. Create a private repo on Forgejo for the vault
3. Clone it locally as the vault folder (or init + add remote)
4. Configure plugin:
   - Auto commit interval: every 10–15 minutes
   - Pull on startup: yes
   - Push after commit: yes
   - Use SSH remote (more reliable than HTTPS for automation)

**SSH key setup:**
```bash
ssh-keygen -t ed25519 -C "obsidian-sync"
# Add public key to Forgejo account settings → SSH Keys
# Add private key path in obsidian-git plugin settings
```

**Mobile note:** obsidian-git on Android works via the plugin's built-in isomorphic-git. iOS is more limited. If mobile sync is critical, consider layering LiveSync on top later (see Phase 2 options).

### Obsidian Wiki Repo

Separate repo on Forgejo for the LLM-generated wiki (the Karpathy-style automated wiki pipeline). Keep vault and wiki as separate repos — different commit cadences and access patterns.

### Key Decisions Made

- **Forgejo over Gitea**: more actively maintained, same API/UX
- **Caddy over Nginx**: simpler config, automatic TLS, Docker-native
- **Dockge over Portainer**: compose-native, zero lock-in, configs remain plain files
- **obsidian-git over LiveSync**: version history is the priority; LiveSync can be added later for real-time sync if needed
- **SSH over HTTPS** for git remotes: more reliable for automated push/pull

### What to Document As You Go

Every service folder should contain:
```
services/
  forgejo/
    docker-compose.yml
    README.md         ← setup notes, port, how to access, backup location
  caddy/
    docker-compose.yml
    Caddyfile
    README.md
  dockge/
    docker-compose.yml
    README.md
```

This documentation becomes the source of truth for the Ansible playbooks in Phase 2.

---

## Phase 2 — Ansible + Full Service Stack

> Not this week. Design locked, implementation deferred.

### Ansible Scope (Bootstrap Layer)

Ansible handles everything **below** the Docker/service layer:

```yaml
# bootstrap.yml covers:
- Tailscale install + auth key
- Docker + Docker Compose install
- Caddy install
- Dockge deploy
- User accounts + SSH hardening
- UFW firewall rules
- Fail2ban
- Automatic security updates (unattended-upgrades)
- Mount points for data volumes
- Cron jobs (backups, DB compaction)
```

Dockge + compose files handle everything above that layer.

### Repo Structure (Target)

```
homelab/                          ← top-level Forgejo repo
  ansible/
    bootstrap.yml
    inventory.yml
    group_vars/
      a6.yml
      zenith.yml
  services/
    forgejo/
      docker-compose.yml
      README.md
    caddy/
      docker-compose.yml
      Caddyfile
    dockge/
      docker-compose.yml
    vikunja/
      docker-compose.yml
    vaultwarden/
      docker-compose.yml
    nextcloud/
      docker-compose.yml
    homepage/
      docker-compose.yml
      config/
        services.yaml
    uptime-kuma/
      docker-compose.yml
    immich/
      docker-compose.yml
    miniflux/
      docker-compose.yml
    linkding/
      docker-compose.yml
  .env.example                    ← documents required secrets, no values
  README.md
```

### Planned Service Stack

#### Core Infrastructure
| Service | Replaces | Notes |
|---|---|---|
| Caddy | — | Reverse proxy, auto TLS |
| Dockge | — | Compose UI |
| Homepage | — | Unified dashboard |
| Uptime Kuma | Better Uptime, Datadog | Health monitoring |
| Watchtower | — | Optional: auto image updates |

#### Git + Dev
| Service | Replaces | Notes |
|---|---|---|
| Forgejo | GitHub | Already Phase 1 |
| Woodpecker CI | GitHub Actions | Native Forgejo integration |

#### Productivity
| Service | Replaces | Notes |
|---|---|---|
| Vikunja | Todoist, Linear | Todos, kanban, CalDAV |
| Outline | Notion | Structured wiki / knowledge base |

#### Files + Storage
| Service | Replaces | Notes |
|---|---|---|
| Nextcloud | Dropbox, Google Drive, Google Calendar/Contacts | CalDAV + CardDAV included |
| Immich | Google Photos | Active development, good mobile app |

#### Passwords + Secrets
| Service | Replaces | Notes |
|---|---|---|
| Vaultwarden | 1Password, Bitwarden cloud | Bitwarden-compatible, tiny footprint |

#### Reading + Bookmarks
| Service | Replaces | Notes |
|---|---|---|
| Miniflux | Feedly | RSS, minimal, fast, good API |
| Linkding | Raindrop, Pocket | Bookmark manager |

### Phase 2 Sequencing

**Foundation first:**
Ansible bootstrap → Caddy → Dockge → Homepage → Uptime Kuma

**Daily drivers next** (highest SaaS replacement value):
Vaultwarden → Nextcloud → Vikunja

**Nice to haves** (add as you feel the absence):
Immich → Miniflux → Linkding → Woodpecker CI → Outline

### Secrets Strategy

- **Now**: `.env` files in a private Forgejo repo (acceptable, low overhead)
- **Later**: Migrate to **Infisical** (self-hosted, Docker image, replaces `.env` files with a proper secrets store)

### Storage & Backup Considerations

- 1TB NVMe is baseline — plan external storage before Nextcloud/Immich fill it
- **3-2-1 backup rule**: 3 copies, 2 media, 1 offsite
- Offsite option: **Backblaze B2** (S3-compatible, cheap per GB)
- Secondary local backup: periodic rsync from A6 → Zenith
- UPS for A6 recommended once it's running critical services

### A6 Hardware Note

Single-channel RAM (16GB, one stick) is a known limitation. Adding a second identical stick enables dual-channel and meaningfully improves memory bandwidth — relevant both for CPU-side LLM inference and general server throughput. Flag this as an upgrade decision before Phase 2 services add memory pressure.

---

## Obsidian Sync — Options Considered

| Approach | Real-time | Version History | Mobile | Chosen |
|---|---|---|---|---|
| obsidian-git + Forgejo | No (scheduled) | ✅ Full Git | Partial | ✅ Phase 1 |
| LiveSync + CouchDB | ✅ Yes | No | ✅ Yes | Phase 2 optional |
| LiveSync + Git cron (hybrid) | ✅ Yes | ✅ Full Git | ✅ Yes | Phase 2 option |
| SMB share over Tailscale | No | No | ❌ Poor | Rejected |

If real-time mobile sync becomes a pain point, add LiveSync on top of obsidian-git without removing Git history — they don't conflict.

---

## LLM Wiki Pipeline (Separate Project)

- **Goal**: Karpathy-style automated wiki — pipeline that researches, drafts, refines long-form articles using local LLMs
- **Primary model**: Qwen3-14B on Zenith (Q4, ~40–65 tok/s)
- **Reasoning model**: DeepSeek-R1-Distill-14B for explanatory content
- **Inference**: Ollama on Zenith
- **Architecture**: A6 orchestrates → pushes tasks to Zenith over Tailscale
- **Storage**: Wiki articles in a dedicated Forgejo repo (Phase 1)
- **30 articles overnight** is feasible as a Zenith GPU batch job (~2 hours)
- Pipeline architecture (orchestration, drafting, refinement stages) TBD

---

## Immediate Next Steps (This Week)

1. [x] Install Docker + Dockge on A6 (geekom) — done 2026-08-22/23, see `services/dockge/`
2. [x] Deploy Forgejo via Dockge — deployed via `docker compose` directly
   (2026-08-25), then symlinked into Dockge's own stacks dir so it's also
   managed from Dockge's UI — see `services/forgejo/`
3. [x] Deploy Caddy, configure Tailscale HTTPS — done 2026-08-25; actual
   hostname is `6l.seahorse-enigmatic.ts.net` (this tailnet's real
   MagicDNS/cert domain), not the placeholder `forgejo.your-tailnet.ts.net`
   above — see `services/caddy/`. Verified end-to-end (`200 OK` through
   the full `tailscale serve → caddy → forgejo` chain).
4. [ ] Create private vault repo + wiki repo on Forgejo
5. [ ] Configure obsidian-git plugin on desktop (SSH key auth)
6. [ ] Test sync: edit → auto commit → push → pull on second device
7. [ ] Create `homelab` repo on Forgejo, push all compose files + READMEs
8. [x] Document everything as you go — ongoing; see `geekom/early_journal.md`
   and each `services/*/README.md`
