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

### Proxmox Storage Setup

#### Option 1: ZFS

If your Proxmox host has extra disks, you can create a ZFS pool and share it to your VM.

**Step 1: Create a ZFS pool on Proxmox**

```bash
# List available disks
lsblk

# Create a ZFS pool called 'storage-pool'
zpool create storage-pool mirror /dev/sdb /dev/sdc

# Or for a single disk:
zpool create storage-pool /dev/sdb
```

**Step 2: Create a ZFS dataset**

```bash
# Create a dataset for sharing
zfs create storage-pool/shared-data

# Set permissions
zfs set mountpoint=/mnt/shared storage-pool/shared-data
```

**Step 3: Share via NFS**

```bash
# Enable NFS on the dataset
zfs set shares NFS=on storage-pool/shared-data

# Or manually configure NFS export in /etc/pve/storage.cfg
```

**Alternative: PCI Passthrough for HBA**

If you want the VM to see the disk controller directly:

1. Go to Proxmox UI → VM → Hardware → Add → PCI Device
2. Select your HBA (Host Bus Adapter)
3. Enable "All Functions" and "Primary GPU" if needed
4. The VM will see the physical disks directly

---

#### Option 2: NFS

**From Proxmox host:**

```bash
# Install NFS server
apt update && apt install nfs-kernel-server

# Create export directory
mkdir -p /mnt/nfs/shared

# Add to /etc/exports
/mnt/nfs/shared  192.168.1.0/24(rw,sync,no_subtree_check,no_root_squash)

# Export immediately
exportfs -a

# Enable and start
systemctl enable nfs-server
systemctl start nfs-server
```

**Mount in Ubuntu VM:**

```bash
# Install NFS client
sudo apt install nfs-common

# Create mount point
sudo mkdir -p /mnt/nfs/shared

# Mount manually
sudo mount -t nfs proxmox-host:/mnt/nfs/shared /mnt/nfs/shared

# Or add to /etc/fstab for auto-mount:
# proxmox-host:/mnt/nfs/shared /mnt/nfs/shared nfs defaults,_netdev 0 0
```

---

#### USB Device Pass-through

**Via Proxmox UI:**

1. Select your VM → Hardware → Add → USB Device
2. Choose one of:
   - **Use physical USB Device** → Select from the dropdown (shows vendor:product)
   - **Use USB Port** → Pass through the entire USB controller
3. Click Add

**Via CLI:**

```bash
# List USB devices
lsusb

# Add USB device to VM (using vendor:product ID)
qm set <vm-id> -usb0 host=046d:c52b

# Or pass through all USB from a specific controller
qm set <vm-id> -hostpci0 00:14.0,xtract=true
```

**Common use cases:**
- Disc ripper (MakeMKV, CD/DVD drive)
- Hardware tokens (YubiKey, etc.)
- Serial devices (Arduino, Raspberry Pi)

**Tips:**
- Use `lsusb` to find your device's vendor:product ID
- For pass-through, the device must not be in use by the Proxmox host
- Some devices require "USB3" setting in VM hardware options

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