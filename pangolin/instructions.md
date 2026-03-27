# Pangolin Architecture & Configuration Guide

This guide outlines the critical configuration steps required to connect your services through the Pangolin reverse proxy, based on the setup used for your home lab.

## Architecture Overview

All external traffic enters via your public IP through your router, hits Pangolin (running on `192.168.1.203`), which then routes to the appropriate internal service based on the domain name.

```
Internet → Router (ports 80/443) → Pangolin/Traefik (192.168.1.203)
                                       ├─ metabase.proxy.shortcentral.com → 192.168.1.138:80
                                       ├─ n8n.proxy.shortcentral.com      → 192.168.1.237:5678
                                       └─ kuma.proxy.shortcentral.com     → 192.168.1.234:3001
```

## 1. Cloudflare DNS Settings

Only a single A record needs to be managed. All subdomains point to it via CNAME records, so when the IP changes, only one record needs updating (handled automatically by the `cloudflare-ddns` Docker container).

| Type  | Name               | Target                   | Notes                         |
|-------|--------------------|--------------------------|-------------------------------|
| A     | `proxy`            | `<your public IP>`       | Auto-updated by cloudflare-ddns|
| CNAME | `metabase.proxy`   | `proxy.shortcentral.com` | Points to Pangolin            |
| CNAME | `n8n.proxy`        | `proxy.shortcentral.com` | Points to Pangolin            |
| CNAME | `kuma.proxy`       | `proxy.shortcentral.com` | Points to Pangolin            |

> **Important:** When adding a new service to Pangolin, always create a CNAME pointing to `proxy.shortcentral.com`, NOT a new A record with an IP address.

## 2. Router Port Forwarding

Forward only ports 80 and 443 to the Pangolin server. Do NOT forward individual app ports (e.g., 5678 for n8n, 3001 for Kuma) directly — Traefik handles internal routing.

| External Port | Internal IP      | Internal Port | Purpose              |
|---------------|------------------|---------------|----------------------|
| 80            | 192.168.1.203    | 80            | HTTP (redirects to HTTPS) |
| 443           | 192.168.1.203    | 443           | HTTPS (all services) |

## 3. Pangolin & Traefik Configuration

All routing rules are managed through the Pangolin Admin UI at `https://proxy.shortcentral.com`.

**Admin Credentials:**
- **Email:** `steve@shortcentral.com`
- **Password:** Defined in `/root/config/config.yml` under `users.server_admin.password`. Pangolin resets the database password to this value on every container restart.

**Adding a new service:**
1. Go to `https://proxy.shortcentral.com` and log in.
2. Create a new **Site** → give it a name (e.g., `myapp`).
3. Create a new **Resource** under that site → set the subdomain (e.g., `myapp.proxy`).
4. Add a **Target** for the resource → enter the internal IP and port of the service.
5. Add a **CNAME** record in Cloudflare pointing `myapp.proxy` → `proxy.shortcentral.com`.

## 4. Maintaining the Cloudflare DDNS Container

The `cloudflare-ddns` Docker container on the Pangolin machine keeps the `proxy.shortcentral.com` A record updated as your public IP changes. It will exit gracefully once done and restart on a cron schedule.

**If the container stops running** (exited status in `docker ps -a`), restart it with:
```bash
# SSH into Proxmox, then enter the Pangolin LXC:
pct enter 109
docker start pangolin-cloudflare-ddns-1
```

## 5. Known Issues & Troubleshooting

### DNS Not Resolving After Adding a CNAME
- Check `dig @8.8.8.8 <hostname>` — if this works, your **router is caching** the old NXDOMAIN response.
- Fix: Run `ipconfig /flushdns` in Windows Command Prompt and restart your browser, or restart your router to flush its DNS cache.

### Access Denied on Pangolin
- The service needs to be assigned to a user role in the Pangolin Admin UI under Sites → Resources → Permissions.

### "Page Not Found" When Accessing Pangolin IP Directly
- Traefik only routes traffic based on the **Host header** (domain name). Accessing via IP or a subdomain not configured in Pangolin will return a 404. This is expected behaviour.
