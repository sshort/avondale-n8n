# Avondale Homelab Update - Walkthrough

Today we successfully recovered admin access to the Pangolin server, added new services to the reverse proxy, and established a specialized health check for your Eufy battery.

## 1. Pangolin Reverse Proxy
- **Admin Access:** Reset the `steve@shortcentral.com` password to `6523Tike!` (as defined in `config.yml`).
- **New Services Added:**
    - **n8n:** [n8n.proxy.shortcentral.com](https://n8n.proxy.shortcentral.com) → `192.168.1.237:5678`
    - **Uptime Kuma:** [kuma.proxy.shortcentral.com](https://kuma.proxy.shortcentral.com) → `192.168.1.234:3001`
- **DNS Records:** Globally verified and working. All subdomains now point to `proxy.shortcentral.com`.
- **Backup:** Full backups of Pangolin and Uptime Kuma (`kuma-data/`) are saved to `/mnt/c/dev/avondale-n8n/pangolin/`.
- **Documentation:** Created [instructions.md](file:///mnt/c/dev/avondale-n8n/pangolin/instructions.md) containing the full architecture and troubleshooting guide.

## 2. Network Diagram
- Created a live [Network Diagram.md](file:///mnt/c/dev/avondale-notes/Network%20Diagram.md) in your Obsidian vault.
- Visualizes the flow from Cloudflare via the Trooli router to your internal LXC containers and Docker services.

## 3. Uptime Kuma Monitoring
- **Metabase & n8n:** Set up health checks.
- **Postgres:** Added cloud (`8.228.33.111`) and local (`homedb`) database monitors.
- **Eufy Station:** Ping monitor for the physical HomeBase (`192.168.1.137`).
- **Front Door Battery:**
    - Type: **Push**
    - **Heartbeat Interval:** Set to `3700` seconds (to match the hourly cron job).
    - Status: **Verified working** (manually triggered to clear the first heartbeat).

## 4. Eufy Security WebSocket Server
- **Installation:** Installed Docker on the Ubuntu VM (`LXC 102`) and deployed `bropat/eufy-security-ws`.
- **Battery Health Check:**
    - Script located at `/opt/eufy-security-ws/check_battery.sh` on the Ubuntu VM.
    - Automation: A **cron job** runs every hour to query the "Front door" camera battery level.
    - Threshold: If the battery level is **>= 20%**, it pings the Kuma Push URL.
    - Integration: Uptime Kuma will alert you if the battery drops below 20% or the server stops checking in.

---

### Useful Commands for You:
- **Check Eufy Logs:** `ssh pve 'pct exec 102 -- docker logs -f eufy-security-ws'`
- **Manual Battery Check:** `ssh pve 'pct exec 102 -- /opt/eufy-security-ws/check_battery.sh'`
- **Pangolin Dashboard:** [https://proxy.shortcentral.com](https://proxy.shortcentral.com)
