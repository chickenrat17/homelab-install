#!/bin/bash
# Homelab Backup Script
# Backs up all Docker volumes to timestamped tar.gz files

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