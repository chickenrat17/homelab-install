#!/bin/bash
# Disable Keycloak auth middleware for all services
# Reverts services to security-headers only

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SERVICE_DIR="$(dirname "$SCRIPT_DIR")/services"

echo "Disabling Keycloak auth middleware..."

# Update all service files
for f in "$SERVICE_DIR"/*.yml; do
    if grep -q "middlewares=keycloak-auth,security-headers" "$f"; then
        sed -i 's/middlewares=keycloak-auth,security-headers/middlewares=security-headers/g' "$f"
        echo "Updated: $(basename $f)"
    fi
done

echo ""
echo "Done! Restart affected containers to apply changes:"
echo "  docker restart \$(docker ps -q --filter 'label=traefik.enable=true')"