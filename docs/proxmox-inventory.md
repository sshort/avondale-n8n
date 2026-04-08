# Proxmox Server Inventory

**Host:** 192.168.1.2

## VMs

| VMID | Name | Status | Purpose |
|------|------|--------|---------|
| 100 | LinuxMint | stopped | Desktop environment |
| 101 | civicrm | stopped | CRM |
| 102 | maps | running | Tile server / mapping |
| 103 | suitecrm | stopped | CRM |
| 104 | phplist | stopped | Email newsletter manager |
| 105 | wordpress | running | CMS |
| 106 | homedb | running | PostgreSQL database for Home Assistant |
| 107 | metabase | running | Business intelligence & data viz |
| 108 | haos15.2 | running | Home Assistant OS (smart home hub) |
| 109 | pangolin | running | Analysis/reporting |
| 110 | n8n | running | Workflow automation engine |
| 111 | sync | running | Syncthing (file sync) |
| 112 | uptimekuma | running | Uptime monitoring & alerts |
| 113 | homecloud | running | Nextcloud (file storage, sync, calendar, contacts) |
| 114 | pihole | running | DNS-level ad blocking |
| 115 | eufy | running | Eufy camera/home integration |
| 116 | ops | running | Operations tooling |
| 117 | appsmith | running | Low-code app platform |
| 118 | planka | running | Project management (Trello alternative) |
| 119 | pdf-tools | running | PDF generation/manipulation |

## Infrastructure

### VM 114 - pihole
| Container/Service | Image/Type | Purpose |
|-------------------|------------|---------|
| Pi-hole FTL | Docker | DNS-level ad blocking |
| Unbound | Native | DNS resolver |

### VM 106 - homedb
| Container/Service | Image/Type | Purpose |
|-------------------|------------|---------|
| PostgreSQL 15 | Docker | Database for Home Assistant |
| Lighttpd + PHP-FPM 8.2 | Native | Web management interface |
| Fail2ban | Native | Intrusion prevention |
| Webmin | Native | System admin panel |
| Postfix | Native | Mail transport |
| Beszel Agent | Native | System monitoring |

### VM 108 - haos15.2
| Container/Service | Image/Type | Purpose |
|-------------------|------------|---------|
| Home Assistant OS | VM | Smart home hub |

## Cloud & Collaboration

### VM 113 - homecloud
| Container/Service | Image/Type | Purpose |
|-------------------|------------|---------|
| Nextcloud | Apache + MariaDB | File sync, calendar, contacts |
| Redis | Native | Cache/sessions |
| Fail2ban | Native | Intrusion prevention |
| Webmin | Native | System admin panel |
| Beszel Agent | Native | System monitoring |

### VM 111 - sync
| Container/Service | Image/Type | Purpose |
|-------------------|------------|---------|
| Syncthing | Native | Open Source Continuous File Synchronization |
| Beszel Agent | Native | System monitoring |

### VM 118 - planka
| Container/Service | Image/Type | Purpose |
|-------------------|------------|---------|
| Planka | Docker (planka-planka-1) | Project management |
| PostgreSQL 16 | Docker (planka-postgres-1) | Planka database |

## Web Applications

### VM 105 - wordpress
| Container/Service | Image/Type | Purpose |
|-------------------|------------|---------|
| WordPress | Apache + MariaDB | CMS |
| Fail2ban | Native | Intrusion prevention |
| Webmin | Native | System admin panel |
| Beszel Agent | Native | System monitoring |

### VM 109 - pangolin
| Container/Service | Image/Type | Purpose |
|-------------------|------------|---------|
| Traefik v3.3.3 | Docker | Reverse proxy |
| Pangolin EE 1.16.2 | Docker | Analysis/reporting |
| Docker Socket Proxy | Docker | Secure Docker access |
| Cloudflare DDNS Updater | Docker | Dynamic DNS |
| Dozzle | Docker | Log viewer |

## Automation & Integration

### VM 110 - n8n
| Container/Service | Image/Type | Purpose |
|-------------------|------------|---------|
| n8n | Docker | Workflow automation engine |
| n8n MCP | Docker | MCP server for n8n |
| Gotenberg | Docker | PDF generation |
| Clubspark Exporter | Docker (local) | Clubspark data export |
| Dozzle | Docker | Log viewer |

### VM 116 - ops
| Container/Service | Image/Type | Purpose |
|-------------------|------------|---------|
| Dozzle | Docker | Operations log viewer |

### VM 117 - appsmith
| Container/Service | Image/Type | Purpose |
|-------------------|------------|---------|
| Appsmith EE | Docker | Low-code app platform |

## Utilities

### VM 112 - uptimekuma
| Container/Service | Image/Type | Purpose |
|-------------------|------------|---------|
| Uptime Kuma | Native (systemd) | Uptime monitoring & alerts |
| Avahi-daemon | Native | mDNS/DNS-SD |
| Beszel Agent | Native | System monitoring |

### VM 119 - pdf-tools
| Container/Service | Image/Type | Purpose |
|-------------------|------------|---------|
| Stirling PDF | Docker | PDF manipulation |
| BentoPDF | Docker | PDF conversion |

### VM 102 - maps
| Container/Service | Image/Type | Purpose |
|-------------------|------------|---------|
| Tile server | Apache? | Mapping service |
| Beszel Agent | Native | System monitoring |

## Analytics & BI

### VM 107 - metabase
| Container/Service | Image/Type | Purpose |
|-------------------|------------|---------|
| Metabase | Native (systemd) + Nginx | Business intelligence & data viz |
| Beszel Agent | Native | System monitoring |

## Smart Home

### VM 115 - eufy
| Container/Service | Image/Type | Purpose |
|-------------------|------------|---------|
| Eufy Security WS | Docker | Eufy camera/home integration |
| Dozzle | Docker | Log viewer |

## Summary

| Category | VMs | Containers/Services |
|----------|-----|---------------------|
| Infrastructure | 3 | 8 |
| Cloud & Collaboration | 3 | 6 |
| Web Applications | 4 | 5 |
| Automation & Integration | 3 | 7 |
| Utilities | 4 | 5 |
| Analytics & BI | 1 | 2 |
| Smart Home | 1 | 1 |
| **Total** | **19 VMs** | **~40 services** |

## Cross-cutting Services

| Service | Purpose | Running On |
|---------|---------|------------|
| Beszel Agent | System monitoring | All VMs |
| Fail2ban | Intrusion prevention | VMs with exposed services |
| Postfix | Mail transport | Most VMs |
| Webmin | System admin panel | Several VMs |
