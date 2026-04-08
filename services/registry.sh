#!/bin/bash
#
# Service Registry - Source of truth for homelab services
# This file defines all services with their metadata, dependencies, and configuration
#

# Service registry - format: SERVICE_NAME|STAGE|DEPENDENCIES|PORTS|REQUIRED
# Using | as delimiter to avoid issues with comma in fields

declare -A SERVICE_REGISTRY=(
    [docker]="core|||true"
    [portainer]="core|||true"
    [traefik]="core|80,443,9090|true"
    [keycloak]="auth|traefik||false"
    [authelia]="auth|traefik||false"
    [sonarr]="media_arr|traefik||false"
    [radarr]="media_arr|traefik||false"
    [lidarr]="media_arr|traefik||false"
    [jellyfin]="media_servers|traefik||false"
    [calibre]="media_servers|traefik||false"
    [navidrome]="media_servers|traefik||false"
    [immich]="media_servers|traefik||false"
    [jellyseerr]="requests|traefik jellyfin||false"
    [homepage]="dashboard|traefik||true"
    [uptime-kuma]="monitoring|traefik||false"
    [grafana]="monitoring|traefik||false"
    [ntfy]="monitoring|traefik||false"
    [vaultwarden]="security|traefik||false"
    [adguard]="security|traefik pihole||false"
    [nextcloud]="storage|traefik||false"
    [minio]="storage|traefik||false"
    [syncthing]="storage|traefik||false"
    [ollama]="ai|traefik||false"
    [openwebui]="ai|traefik ollama||false"
    [pihole]="core|53,8081|false"
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
    # Fields: 1=stage, 2=dependencies, 3=ports, 4=required
    echo "$entry" | cut -d'|' -f2
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
    # Fields: 1=stage, 2=dependencies, 3=ports, 4=required
    echo "$entry" | cut -d'|' -f3
}

# Function to get stage for a service
get_service_stage() {
    local service=$1
    local entry="${SERVICE_REGISTRY[$service]:-}"
    # Fields: 1=stage, 2=dependencies, 3=ports, 4=required
    echo "$entry" | cut -d'|' -f1
}

# Export functions for use in install.sh
export -f get_service_metadata
export -f get_service_dependencies
export -f get_stage_services
export -f is_service_required
export -f get_service_ports
export -f get_service_stage
