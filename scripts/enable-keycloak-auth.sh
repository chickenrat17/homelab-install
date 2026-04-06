#!/bin/bash
# Enable Keycloak auth middleware for all services
# Run this after Keycloak is configured and running

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SERVICE_DIR="$(dirname "$SCRIPT_DIR")/services"

# Check if Keycloak is running
if ! docker ps --format '{{.Names}}' | grep -q "^keycloak$"; then
    echo "Error: Keycloak is not running. Install and configure Keycloak first."
    exit 1
fi

echo "Enabling Keycloak auth middleware..."

# Update all service files
for f in "$SERVICE_DIR"/*.yml; do
    if grep -q "middlewares=security-headers" "$f"; then
        sed -i 's/middlewares=security-headers/middlewares=keycloak-auth,security-headers/g' "$f"
        echo "Updated: $(basename $f)"
    fi
done

echo ""
echo "Done! Restart affected containers to apply changes:"
echo "  docker restart \$(docker ps -q --filter 'label=traefik.enable=true')"
echo ""
echo "Or restart specific services:"
echo "  docker restart jellyfin radarr sonarr"