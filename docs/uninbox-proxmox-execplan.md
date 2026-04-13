# Install UnInbox On Proxmox And Register It In Homepage, Uptime Kuma, And Beszel

This ExecPlan is a living document. The sections `Progress`, `Surprises & Discoveries`, `Decision Log`, and `Outcomes & Retrospective` must be kept up to date as work proceeds.

This document is maintained in accordance with [/mnt/c/dev/PLAN.md](/mnt/c/dev/PLAN.md).

## Purpose / Big Picture

After this work completes, UnInbox will be reachable on the local network from a dedicated Proxmox LXC instead of being mixed into the hypervisor itself. The new service will also appear in Homepage, have an Uptime Kuma monitor, and expose host metrics to Beszel. The visible proof is that visiting the UnInbox URL returns the web app, Homepage shows a new entry, Uptime Kuma shows a new monitor, and Beszel shows the new container as a monitored host.

## Progress

- [x] (2026-04-11 10:20Z) Confirmed SSH access to `pve` with the dedicated key in `/home/steve/.ssh/id_ed25519_proxmox` and updated `/home/steve/.ssh/config` to use it.
- [x] (2026-04-11 10:27Z) Confirmed Proxmox has free `local-lvm` storage, an Ubuntu 24.04 LXC template, and existing Docker-in-LXC containers that use `nesting=1`.
- [x] (2026-04-11 10:34Z) Confirmed Homepage runs in LXC 110 with config mounted from `/opt/homepage/config`.
- [x] (2026-04-11 10:41Z) Confirmed Uptime Kuma runs in LXC 112 as a native systemd service on port `3001`.
- [x] (2026-04-11 10:48Z) Researched upstream UnInbox and confirmed there is no simple production installer; the workable local deployment shape is local Docker dependencies plus five Node services.
- [x] (2026-04-11 17:18Z) Created Proxmox LXC `120` with hostname `uninbox`, static address `192.168.1.239`, `nesting=1`, `keyctl=1`, `8 GiB` RAM, and `30 GiB` root disk.
- [x] (2026-04-11 17:23Z) Installed Docker, Docker Compose v2, Node 20, pnpm 9.10.0, and build tooling inside the new container.
- [x] (2026-04-11 17:31Z) Cloned `un/inbox`, generated `.env.local`, started the dependency containers, pushed the database schema, built all services, and created an enabled `uninbox.service` systemd unit.
- [x] (2026-04-11 17:35Z) Added UnInbox to Homepage in `/mnt/c/dev/avondale-n8n/homepage/config/services.yaml` and pushed the live config into LXC 110.
- [x] (2026-04-11 17:38Z) Added an Uptime Kuma HTTP monitor for `http://192.168.1.239:3000` in LXC 112 and verified heartbeats are being recorded.
- [x] (2026-04-11 17:45Z) Installed Beszel agent in the new container, registered its fingerprint in the Proxmox Beszel hub database, and verified the new system is `up`.
- [x] (2026-04-11 17:46Z) Verified the UnInbox web app returns HTTP 200 on `http://192.168.1.239:3000`.

## Surprises & Discoveries

- Observation: The Proxmox host itself does not run Docker or Podman.
  Evidence: `ssh pve "command -v docker || true; command -v podman || true"` returned no runtime path.

- Observation: UnInbox upstream documents a developer-oriented stack, not a packaged production deployment.
  Evidence: the upstream `README.md` says self-hosting is possible but requires manual configuration for email, and the provided compose file under `packages/local-docker/docker-compose.yml` only covers MySQL, Redis, MinIO, and Soketi.

- Observation: Homepage is not reading directly from this workspace at runtime; the live container uses `/opt/homepage/config` inside LXC 110.
  Evidence: `docker inspect homepage --format "{{json .Mounts}}"` in LXC 110 shows a bind mount from `/opt/homepage/config` to `/app/config`.

- Observation: The upstream local dependency stack currently references `bitnami/minio:latest`, which no longer resolves.
  Evidence: `docker compose --project-directory packages/local-docker up -d` failed with `failed to resolve reference "docker.io/bitnami/minio:latest": not found`.

- Observation: Beszel hub registration is not fully agent-side; the Proxmox hub stores explicit `systems` and `fingerprints` rows in `/opt/beszel/beszel_data/data.db`.
  Evidence: querying the hub database showed the `systems` and `fingerprints` tables, and the new agent only connected successfully after inserting the `uninbox` fingerprint row.

## Decision Log

- Decision: Deploy UnInbox in a new LXC instead of on the Proxmox host.
  Rationale: The host is the hypervisor and does not already run the application runtime needed by UnInbox. Existing application services are already separated into LXCs, and Docker-in-LXC is already in use on this node.
  Date/Author: 2026-04-11 / Codex

- Decision: Use the upstream local dependency stack plus built Node services as the first working deployment shape.
  Rationale: Upstream does not provide a complete production compose stack. Using the documented dependency containers and the repository build/start scripts is the most direct route to a working install that can be validated now.
  Date/Author: 2026-04-11 / Codex

- Decision: Override only the MinIO service in `packages/local-docker/docker-compose.override.yml` inside the guest instead of patching the whole upstream compose stack.
  Rationale: Only one image reference was stale. A narrow override kept the deployment close to upstream while fixing the broken dependency quickly.
  Date/Author: 2026-04-11 / Codex

- Decision: Register the new Beszel fingerprint directly in the hub database after the agent connected but was rejected.
  Rationale: The agent runtime and network path were already correct. The missing piece was a hub-side `systems` and `fingerprints` mapping for the new container.
  Date/Author: 2026-04-11 / Codex

## Outcomes & Retrospective

UnInbox is now running in Proxmox LXC `120` at `http://192.168.1.239:3000`, managed by systemd, and backed by local Docker sidecars for MySQL, Redis, MinIO, and Soketi. Homepage has a live UnInbox card, Uptime Kuma has an active HTTP monitor and stored heartbeats, and Beszel shows the new `uninbox` system as `up` with system stats.

The remaining gap is expected and upstream-driven: this deployment uses the upstream local-mode mail configuration, so real production mail routing and domain setup are still manual follow-up work if the goal is full external send/receive rather than a working local UnInbox stack.

## Context and Orientation

The relevant local repository is `/mnt/c/dev/avondale-n8n`. Proxmox inventory is documented in `/mnt/c/dev/avondale-n8n/docs/proxmox-inventory.md`. Homepage source configuration lives in `/mnt/c/dev/avondale-n8n/homepage/config/services.yaml`, but the live Homepage instance in Proxmox LXC 110 reads from `/opt/homepage/config/services.yaml`. Uptime Kuma runs in Proxmox LXC 112. Beszel hub is available on `http://192.168.1.2:8090` and existing containers use a local `beszel-agent` systemd service that points to that hub.

An LXC is a Linux container managed by Proxmox. In this environment, several LXCs already run Docker inside the guest by enabling the Proxmox container feature `nesting=1`. UnInbox is a Node-based monorepo with five services: `web`, `mail-bridge`, `platform`, `storage`, and `worker`. Upstream also expects MySQL, Redis, MinIO, and Soketi to be present.

## Plan of Work

Create a new Ubuntu 24.04 unprivileged LXC on `local-lvm` with Docker nesting enabled, onboot enabled, and a hostname of `uninbox`. Use the existing LXC pattern from containers such as 110 and 112, but give UnInbox more memory and disk than the lightweight monitoring containers because the Node build is heavier. The completed deployment uses VMID `120`, `192.168.1.239/24`, `2` cores, `8 GiB` RAM, and a `30 GiB` root disk.

Clone `https://github.com/un/inbox.git` into the new container, create a `.env.local` derived from upstream `.env.local.example`, and change the public-facing URLs to the container address instead of `localhost` where needed for browser access. Start the dependency stack from `packages/local-docker/docker-compose.yml`, run `pnpm db:push`, build the repository, and create a systemd unit that runs `pnpm start:all` from the repository root after the dependency containers are up.

Once the app is reachable, add an UnInbox entry to `/mnt/c/dev/avondale-n8n/homepage/config/services.yaml`, copy the resulting file to the live Homepage config on LXC 110, and restart the Homepage container. Then add a Kuma monitor against the UnInbox web endpoint and install Beszel agent in the new LXC. Because Beszel hub stores explicit registration rows in `/opt/beszel/beszel_data/data.db`, the completed process also inserts the new `uninbox` system and fingerprint mapping on the Proxmox host.

## Concrete Steps

From `/mnt/c/dev`, run remote Proxmox commands via `ssh pve ...` to create and configure the new LXC. Then use `pct exec <vmid> -- ...` to install packages and configure the guest. Use `scp` or `ssh ... cat > file` only for moving finished config files into the live Homepage host after the local repository copy has been updated.

The expected shape after deployment is:

    pct list
    ... 120 uninbox running ...

    curl -I http://192.168.1.239:3000
    HTTP/1.1 200 OK

    docker ps
    mysql-primary-db
    planetscale-simulator-proxy
    redis-cache-db
    minio-storage
    soketi-server

## Validation and Acceptance

Validation is complete when all of the following are true:

1. The new LXC is running and starts automatically after a reboot.
2. Visiting the UnInbox web URL from the LAN returns the application.
3. The UnInbox process survives a service restart through systemd.
4. Homepage shows an UnInbox card that links to the working web URL.
5. Uptime Kuma shows a healthy monitor for the UnInbox web endpoint.
6. Beszel shows the new container as a monitored host.

## Idempotence and Recovery

The container creation step is the only non-idempotent part. Before re-running it, check whether the chosen VMID already exists with `pct status <vmid>`. Package installation and repository setup inside the guest can be re-run safely. If the app build fails, keep the dependency containers running and re-run `pnpm install`, `pnpm db:push`, and `pnpm build:all` after correcting the environment values.

If Homepage config deployment fails, restore `/opt/homepage/config/services.yaml` from a timestamped backup created immediately before copying the new file. If the Kuma monitor cannot be added automatically, record the blocker and keep the new UnInbox endpoint and Homepage entry in place so the remaining work is isolated.

## Artifacts and Notes

Important evidence gathered before implementation:

    ssh pve "pvesm status"
    local-lvm active with more than 1.3 TB available

    ssh pve "pct config 110"
    features: nesting=1
    ostype: ubuntu
    rootfs: local-lvm:vm-110-disk-0,size=25G

    ssh pve "pct exec 110 -- docker inspect homepage --format '{{json .Mounts}}'"
    /opt/homepage/config -> /app/config

Important evidence after implementation:

    ssh pve "pct exec 120 -- systemctl is-active uninbox beszel-agent"
    active
    active

    ssh pve "pct exec 120 -- curl -I http://192.168.1.239:3000"
    HTTP/1.1 200 OK

    ssh pve "sqlite3 /opt/beszel/beszel_data/data.db \"select name,status from systems where name = 'uninbox';\""
    uninbox|up

    ssh pve "pct exec 112 -- python3 -c '... query monitor table ...'"
    [(34, 'UnInbox', 'http', 'http://192.168.1.239:3000', 1)]

## Interfaces and Dependencies

The deployment depends on:

- Proxmox `pct`, `pvesm`, and `pvesh` on host `pve`.
- Ubuntu 24.04 LXC template `local:vztmpl/ubuntu-24.04-standard_24.04-2_amd64.tar.zst`.
- Docker Engine and Docker Compose plugin inside the new guest.
- Node 20 and pnpm 9 or newer inside the new guest.
- The upstream repository `https://github.com/un/inbox.git`.
- Homepage config file `/opt/homepage/config/services.yaml` in LXC 110.
- Uptime Kuma service in LXC 112.
- Beszel hub at `http://192.168.1.2:8090`.

Revision note: created this plan after confirming the current Proxmox, Homepage, Kuma, and UnInbox deployment shape so the remaining work can be executed repeatably.
Revision note: updated this plan after completing the live deployment, documenting the MinIO override, Beszel hub registration requirement, and the final validation evidence.
