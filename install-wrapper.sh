#!/bin/bash
#
# Homelab Installer Wrapper - Sources registry then runs install.sh
#

# Source the service registry first
source "$HOMELAB_DIR/services/registry.sh"

# Run the original install logic
source "$HOMELAB_DIR/install.sh"
