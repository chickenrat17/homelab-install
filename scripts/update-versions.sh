#!/bin/bash
# Homelab Version Update Script
# Pull latest images for all services

echo "=== Homelab Image Update ==="
echo "Checking for updates..."

cd "$(dirname "$0")/.."

# Get all service compose files
SERVICES=$(find services -name "*.yml" -type f | sort)

for svc in $SERVICES; do
  echo ""
  echo "--- $svc ---"
  # Extract image name
  image=$(grep "^    image:" "$svc" | head -1 | awk '{print $3}')
  if [ -n "$image" ]; then
    echo "Current: $image"
    # Pull and show size difference
    docker pull "$image" 2>/dev/null || echo "  Pull failed"
  fi
done

echo ""
echo "=== Update complete ==="
echo "Run 'docker compose up -d' to restart with new images"