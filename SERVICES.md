# Services on n8n Server (192.168.1.237)

This file lists the active services running via Docker on the n8n server.

## Core Services

| Service | URL | Description |
| :--- | :--- | :--- |
| **n8n** | [https://n8n.proxy.shortcentral.com](https://n8n.proxy.shortcentral.com) | Primary automation platform. |
| **Pi-hole** | [http://192.168.1.212/admin](http://192.168.1.212/admin) | Network-wide ad blocking. |
| **homedb** | [192.168.1.248](192.168.1.248) | PostgreSQL database server. |
| **metabase** | [http://192.168.1.138:3000](http://192.168.1.138:3000) | Business intelligence and dashboards. |
| **syncthing** | [http://192.168.1.133:8384](http://192.168.1.133:8384) | File synchronization service. |
| **homecloud** | [http://192.168.1.201](http://192.168.1.201) | Nextcloud / private storage. |
| **ClubSpark Exporter** | [http://192.168.1.237:3001/health](http://192.168.1.237:3001/health) | Exporter API (Health check). |

## Monitoring & Management

| Service | URL | Description |
| :--- | :--- | :--- |
| **Dozzle** | [http://192.168.1.237:8888](http://192.168.1.237:8888) | Real-time log viewer for all containers. |
| **Portainer CE** | [https://192.168.1.237:9443](https://192.168.1.237:9443) | GUI for container and stack management. |

## Uptime Kuma Monitoring (at http://kuma:3001)

| Service | Type | URL | Note |
| :--- | :--- | :--- | :--- |
| **Dozzle** | HTTP(s) | `http://192.168.1.237:8888` | Status: `200-405` |
| **Portainer** | HTTP(s) | `https://192.168.1.237:9443` | Ignore TLS: `Yes` |
| **Exporter** | HTTP(s) | `http://192.168.1.237:3001/health` | Status: `200` |
| **homedb** | TCP Port | `192.168.1.248:5432` | Postgres |
| **metabase** | HTTP(s) | `http://192.168.1.138:3000` | Status: `200` |
| **syncthing** | HTTP(s) | `http://192.168.1.133:8384` | Status: `200` |
| **homecloud** | HTTP(s) | `http://192.168.1.201` | Status: `200` |

---
*Note: Portainer also listens on http://192.168.1.237:9000 if HTTPS is not required.*
