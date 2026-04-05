# Homelab Installer

One-command homelab setup with Docker, Portainer, Traefik, and OpenClaw.

## Architecture Overview

- Homelab runs inside an **Ubuntu Server VM** on Proxmox
- All services run as **Docker containers** inside that VM
- The installer runs *inside* the Ubuntu VM, not on Proxmox directly

## Proxmox Setup Guide

1. Install Proxmox VE on bare metal
2. Create an Ubuntu Server 22.04 VM
3. Pass through ZFS storage (PCI passthrough or NFS)
4. Pass through USB devices if needed (disc ripper, etc.)
5. SSH into the VM and run the installer

## Storage Options

- ZFS dataset → bind mount into containers
- NFS mount → Docker volume → container

## Hardware Pass-through

- USB devices → Proxmox USB passthrough → VM

## Quick Start

```bash
# Run the installer
sudo bash ~/homelab-install/install.sh
```

## What's Installed

- **Docker** - Container runtime
- **Portainer** - Web-based container management (https://your-ip:9443)
- **Traefik** - Reverse proxy with automatic SSL (http://your-ip:8080)

## Service Definitions

Place Docker Compose files in `services/` folder:

| Service | File | Description |
|---------|------|-------------|
| Jellyfin | `services/jellyfin.yml` | Media server |
| Vaultwarden | `services/vaultwarden.yml` | Password manager |
| Uptime Kuma | `services/uptime-kuma.yml` | Monitoring |

## Adding More Services

1. Copy a service compose file from `services/`
2. Edit for your environment (paths, domain)
3. Run: `docker compose -f services/your-service.yml up -d`

## Project Structure

```
homelab-install/
├── install.sh          # Main installer
├── services/          # Docker Compose definitions
├── docs/              # Service documentation
└── config/            # Service configs (Traefik, etc.)
```

## OpenClaw Integration

OpenClaw serves as the homelab "nerve center" for:
- Service status queries
- Configuration help
- Uptime monitoring alerts
- Basic container management

## Security Notes

- Default: No exposed ports (behind Traefik)
- Use Traefik with Let's Encrypt for SSL
- Consider Cloudflare Tunnel for external access
- Change default passwords immediately