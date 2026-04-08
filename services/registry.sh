#!/bin/bash
#
# Service Registry - Source of truth for homelab services
# This file defines all services with their metadata, dependencies, and configuration
#

# Service registry - format: SERVICE_NAME|STAGE|DEPENDENCIES|PORTS|REQUIRED|DESCRIPTION
# Using | as delimiter

declare -A SERVICE_REGISTRY=(
    [docker]="core|||true|Container runtime (installed by script)"
    [portainer]="core|||true|Container management UI"
    [traefik]="core|80,443,9090|true|Reverse proxy with automatic SSL"
    [keycloak]="auth|traefik||false|Identity and access management"
    [authelia]="auth|traefik||false|Two-factor authentication portal"
    [sonarr]="media_arr|traefik||false|TV show management"
    [radarr]="media_arr|traefik||false|Movie management"
    [lidarr]="media_arr|traefik||false|Music collection management"
    [jellyfin]="media_servers|traefik||false|Media server (free)"
    [calibre]="media_servers|traefik||false|Ebook management"
    [navidrome]="media_servers|traefik||false|Music streaming server"
    [immich]="media_servers|traefik||false|Photo and video backup (AI)"
    [jellyseerr]="requests|traefik jellyfin||false|Request management for media"
    [homepage]="dashboard|traefik||true|Homelab dashboard"
    [uptime-kuma]="monitoring|traefik||false|Self-hosted monitoring"
    [grafana]="monitoring|traefik||false|Metrics dashboards"
    [ntfy]="monitoring|traefik||false|Push notifications"
    [vaultwarden]="security|traefik||false|Password manager"
    [adguard]="security|traefik pihole||false|DNS-level ad blocking"
    [nextcloud]="storage|traefik||false|File sync and sharing"
    [minio]="storage|traefik||false|S3-compatible storage"
    [syncthing]="storage|traefik||false|File synchronization"
    [ollama]="ai|traefik||false|Local AI models"
    [openwebui]="ai|traefik ollama||false|AI model web interface"
    [pihole]="core|53,8081|false|DNS server (required by default)"
)

# Dependency graph - for explicit dependency resolution
declare -A SERVICE_DEPENDENCIES=(
    ["authelia"]="traefik"
    ["keycloak"]="traefik"
    ["jellyseerr"]="traefik jellyfin"
    ["immich"]="traefik"
    ["ollama"]="traefik"
    ["openwebui"]="traefik ollama"
)

# Stage definitions - service names as they appear in compose files (with hyphen)
STAGE1_CORE=("docker" "portainer" "traefik")
STAGE2_AUTH=("keycloak" "authelia")
STAGE3_MEDIA_ARR=("sonarr" "radarr" "lidarr")
STAGE4_MEDIA_SERVERS=("jellyfin" "calibre" "navidrome" "immich")
STAGE5_REQUESTS=("jellyseerr")
STAGE6_DASHBOARD=("homepage")
STAGE7_MONITORING=("uptime-kuma" "grafana" "ntfy")
STAGE8_SECURITY=("vaultwarden" "adguard")
STAGE9_STORAGE=("nextcloud" "minio" "syncthing")
STAGE10_AI=("ollama" "openwebui")

# All stages array
ALL_STAGES=(
    "STAGE1_CORE"
    "STAGE2_AUTH"
    "STAGE3_MEDIA_ARR"
    "STAGE4_MEDIA_SERVERS"
    "STAGE5_REQUESTS"
    "STAGE6_DASHBOARD"
    "STAGE7_MONITORING"
    "STAGE8_SECURITY"
    "STAGE9_STORAGE"
    "STAGE10_AI"
)

# Default selected services for guided install
DEFAULT_SELECTED=("portainer" "traefik" "homepage" "pihole")

# Function to get service metadata from registry
get_service_metadata() {
    local service=$1
    local entry="${SERVICE_REGISTRY[$service]:-}"
    echo "$entry"
}

# Function to get service dependencies from registry
get_service_dependencies() {
    local service=$1
    local entry="${SERVICE_REGISTRY[$service]:-}"
    # Fields: 1=stage, 2=dependencies, 3=ports, 4=required, 5=description
    echo "$entry" | cut -d'|' -f2
}

# Function to get service description from registry
get_service_description() {
    local service=$1
    local entry="${SERVICE_REGISTRY[$service]:-}"
    # Fields: 1=stage, 2=dependencies, 3=ports, 4=required, 5=description
    echo "$entry" | cut -d'|' -f5
}

# Function to get all services in a stage
get_stage_services() {
    local stage=$1
    eval "echo \"\${STAGE_SERVICES[$stage]}\""
}

# Function to check if service is required
is_service_required() {
    local service=$1
    local entry="${SERVICE_REGISTRY[$service]:-}"
    [[ "$entry" == *"true"* ]]
}

# Function to get ports for a service
get_service_ports() {
    local service=$1
    local entry="${SERVICE_REGISTRY[$service]:-}"
    # Fields: 1=stage, 2=dependencies, 3=ports, 4=required, 5=description
    echo "$entry" | cut -d'|' -f3
}

# Function to get stage for a service
get_service_stage() {
    local service=$1
    local entry="${SERVICE_REGISTRY[$service]:-}"
    # Fields: 1=stage, 2=dependencies, 3=ports, 4=required, 5=description
    echo "$entry" | cut -d'|' -f1
}

# Export functions for use in install.sh
export -f get_service_metadata
export -f get_service_dependencies
export -f get_service_description
export -f get_stage_services
export -f is_service_required
export -f get_service_ports
export -f get_service_stage
