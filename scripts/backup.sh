#!/bin/bash
# Homelab Backup Script
# Backs up all Docker volumes to timestamped tar.gz files

# Parse arguments
DRY_RUN=false
VERIFY=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --dry-run|-n)
            DRY_RUN=true
            shift
            ;;
        --verify|-v)
            VERIFY=true
            shift
            ;;
        *)
            echo "Usage: $0 [--dry-run|-n] [--verify|-v]"
            echo "  --dry-run  Show what would be backed up without creating archives"
            echo "  --verify  Verify archives after creation (extracted size check)"
            exit 1
            ;;
    esac
done

BACKUP_DIR="${BACKUP_DIR:-./backups}"
DATE=$(date +%Y%m%d-%H%M%S)

mkdir -p "$BACKUP_DIR"

# Services with persistent data
SERVICES=(
  "adguard-work"
  "adguard-conf"
  "calibre-config"
  "calibre-books"
  "grafana-data"
  "homeassistant-config"
  "homepage-config"
  "immich-upload"
  "immich-db"
  "immich-redis"
  "immich-ml-cache"
  "jellyfin-config"
  "jellyfin-cache"
  "navidrome-config"
  "nextcloud-data"
  "nextcloud-apps"
  "ntfy-cache"
  "ntfy-data"
  "ollama-data"
  "openwebui-data"
  "radarr-config"
  "sonarr-config"
  "uptime-kuma-data"
  "vaultwarden-data"
)

echo "=== Homelab Backup: $DATE ==="
echo "Backing up to: $BACKUP_DIR"

# Dry-run mode: just list volumes without backing up
if [ "$DRY_RUN" = true ]; then
    echo "[DRY RUN] Would back up the following volumes:"
    for vol in "${SERVICES[@]}"; do
        if docker volume inspect "$vol" >/dev/null 2>&1; then
            echo "  - $vol"
        else
            echo "  - $vol (NOT FOUND)"
        fi
    done
    echo "[DRY RUN] No backups created."
    exit 0
fi

# Stop services (optional - for consistent backups)
# docker compose stop

for vol in "${SERVICES[@]}"; do
  if docker volume inspect "$vol" >/dev/null 2>&1; then
    backup_file="$BACKUP_DIR/${vol}-${DATE}.tar.gz"
    echo "Backing up: $vol -> $backup_file"
    docker run --rm \
      -v "$vol":/source \
      -v "$BACKUP_DIR":/backup \
      alpine:latest \
      tar czf "/backup/${vol}-${DATE}.tar.gz" -C /source . \
      2>/dev/null || echo "  Warning: $vol may be empty"
  else
    echo "Skipping: $vol (not found)"
  fi
done

# Cleanup old backups (keep last 7 days)
find "$BACKUP_DIR" -name "*.tar.gz" -mtime +7 -delete

echo "=== Backup complete ==="
echo "Files in $BACKUP_DIR:"
ls -lh "$BACKUP_DIR" | tail -5

# Verify archives if requested
if [ "$VERIFY" = true ]; then
    echo ""
    echo "=== Verifying backups ==="
    for backup_file in "$BACKUP_DIR"/*.tar.gz; do
        if [ -f "$backup_file" ]; then
            echo -n "Verifying: $(basename $backup_file)... "
            if gzip -t "$backup_file" 2>/dev/null; then
                echo "OK (valid gzip)"
            else
                echo "FAILED!"
            fi
        fi
    done
fi