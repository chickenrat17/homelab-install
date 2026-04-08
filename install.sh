#!/bin/bash
#
# Homelab Installer - One command to setup your homelab
# Usage: bash <(curl -sL get-homelab.example)
#

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Config
HOMELAB_DIR="$HOMELAB_DIR"
SERVICE_DIR="$HOMELAB_DIR/services"
CONFIG_DIR="$HOMELAB_DIR/config"

# Fix: Use SUDO_USER's home if running with sudo
if [[ -n "$SUDO_USER" ]]; then
    HOMELAB_DIR="/home/$SUDO_USER/homelab-install"
    SERVICE_DIR="$HOMELAB_DIR/services"
    CONFIG_DIR="$HOMELAB_DIR/config"
fi

#######################################
# Utility Functions
#######################################

# Auto-detect host IP address
auto_detect_ip() {
    local ip=""
    ip=$(ip route get 1.1.1.1 2>/dev/null | awk '{print $7}')
    if [[ -z "$ip" ]]; then
        ip=$(hostname -I 2>/dev/null | awk '{print $1}')
    fi
    if [[ -z "$ip" ]]; then
        ip=$(docker network inspect bridge 2>/dev/null | grep '"Gateway"' | awk -F'"' '{print $4}')
    fi
    echo "$ip"
}

# Prompt for host IP if auto-detection fails
prompt_host_ip() {
    local ip=$(auto_detect_ip)
    if [[ -z "$ip" ]]; then
        log_warn "Could not auto-detect host IP address"
        read -p "Please enter your host's IP address on the local network: " ip
        if [[ -z "$ip" ]]; then
            log_error "IP address is required"
            exit 1
        fi
        if ! [[ "$ip" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
            log_error "Invalid IP address format: $ip"
            exit 1
        fi
    fi
    echo "$ip"
}

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[OK]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

confirm() {
    read -p "$1 [y/N]: " response
    case "$response" in
        [yY][eE][sS]|[yY]) return 0 ;;
        *) return 1 ;;
    esac
}

# Validate required environment variables
validate_env_vars() {
    log_info "Validating environment variables..."
    
    source "$HOMELAB_DIR/.env" 2>/dev/null || true
    
    local missing=()
    
    # Required variables (no defaults - user must set these)
    [[ -z "$DOMAIN" ]] && missing+=("DOMAIN")
    [[ -z "$KEYCLOAK_ADMIN_PASSWORD" ]] && missing+=("KEYCLOAK_ADMIN_PASSWORD")
    [[ -z "$GF_SECURITY_ADMIN_PASSWORD" ]] && missing+=("GF_SECURITY_ADMIN_PASSWORD")
    
    # Validate DOMAIN format
    if [[ -n "$DOMAIN" ]]; then
        if [[ ! "$DOMAIN" =~ ^[a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?(\.[a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?)*$ ]]; then
            log_warn "DOMAIN '$DOMAIN' may not be a valid domain format"
        fi
        # Warn about .local domains (not Let's Encrypt compatible)
        if [[ "$DOMAIN" == *".local" ]] || [[ "$DOMAIN" == *".localtld" ]]; then
            log_warn "DOMAIN '$DOMAIN' is a .local domain - Let's Encrypt will NOT work"
            log_warn "Use internal SSL or Cloudflare Tunnel for external access"
        fi
    fi
    
    if [[ ${#missing[@]} -gt 0 ]]; then
        log_error "Missing required variables in .env: ${missing[*]}"
        log_info "Edit $HOMELAB_DIR/.env and set these values before continuing."
        exit 1
    fi
    
    log_success "All required variables set"
}

# Prompt for admin password
prompt_admin_password() {
    source "$HOMELAB_DIR/.env" 2>/dev/null || true
    
    if [[ -z "$ADMIN_PASSWORD" ]]; then
        echo ""
        log_info "Set your admin password for homelab services:"
        read -s -p "Password: " ADMIN_PASSWORD
        echo ""
        read -s -p "Confirm: " ADMIN_PASSWORD_CONFIRM
        echo ""
        
        if [[ "$ADMIN_PASSWORD" != "$ADMIN_PASSWORD_CONFIRM" ]]; then
            log_error "Passwords do not match"
            exit 1
        fi
        
        if [[ ${#ADMIN_PASSWORD} -lt 8 ]]; then
            log_error "Password must be at least 8 characters"
            exit 1
        fi
        
        # Save to .env
        echo "ADMIN_PASSWORD=$ADMIN_PASSWORD" >> "$HOMELAB_DIR/.env"
        log_success "Admin password saved"
    else
        log_info "Admin password already configured"
    fi
}

# Check for pre-flight conditions
preflight_checks() {
    log_info "Running pre-flight checks..."
    
    # Check docker group membership
    if ! id -nG "$SUDO_USER" | grep -qw docker; then
        log_warn "User $SUDO_USER is not in the docker group"
        if confirm "Add $SUDO_USER to docker group?"; then
            usermod -aG docker "$SUDO_USER" 2>/dev/null || true
            log_success "User added to docker group"
            log_info "You may need to log out and back in for changes to take effect"
        else
            log_error "Docker operations will fail without group membership"
            exit 1
        fi
    fi
    
    # Check for port conflicts (common ones)
    local conflicts=()
    
    # Check port 80
    if ss -tlnp 2>/dev/null | grep -q ":80 "; then
        conflicts+=("port 80 (HTTP)")
    fi
    
    # Check port 443
    if ss -tlnp 2>/dev/null | grep -q ":443 "; then
        conflicts+=("port 443 (HTTPS)")
    fi
    
    # Check port 53 (only if adguard selected)
    if echo "$SELECTED_SERVICES" | grep -qw adguard; then
        if ss -tlnp 2>/dev/null | grep -q ":53 "; then
            conflicts+=("port 53 (DNS)")
        fi
    fi
    
    if [[ ${#conflicts[@]} -gt 0 ]]; then
        log_warn "Port conflicts detected: ${conflicts[*]}"
        if echo "$SELECTED_SERVICES" | grep -qw adguard; then
            if confirm "Stop systemd-resolved to free port 53?"; then
                systemctl stop systemd-resolved 2>/dev/null || true
                systemctl disable systemd-resolved 2>/dev/null || true
                log_success "systemd-resolved stopped"
            fi
        fi
    fi
    
    log_success "Pre-flight checks passed"
}

# Check for pre-existing containers from a previous install
check_existing_containers() {
    log_info "Checking for existing containers..."
    
    local containers=$(docker ps -aq --filter "name=caddy" --filter "name=adguard" --filter "name=homepage" --filter "name=jellyfin" --filter "name=grafana" --filter "name=keycloak" 2>/dev/null | wc -l)
    
    if [[ $containers -gt 0 ]]; then
        log_warn "Found existing containers from a previous installation"
        if confirm "Remove existing containers and volumes?"; then
            docker compose -f "$HOMELAB_DIR/docker-compose.yml" down -v 2>/dev/null || true
            log_success "Cleaned up existing containers"
        fi
    fi
}

# Check if running as root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "This script must be run as root (use sudo)"
        exit 1
    fi
}

# Detect OS
detect_os() {
    if [[ -f /etc/os-release ]]; then
        . /etc/os-release
        OS=$ID
        VERSION=$VERSION_ID
    else
        log_error "Cannot detect OS"
        exit 1
    fi
    
    if [[ "$OS" != "ubuntu" ]]; then
        log_warn "This script is designed for Ubuntu. Detected: $OS"
        if ! confirm "Continue anyway?"; then
            exit 1
        fi
    fi
}

#######################################
# Core Installation
#######################################

install_docker() {
    log_info "Installing Docker..."
    
    # Remove old versions
    apt-get remove -y docker docker-engine docker.io containerd runc 2>/dev/null || true
    
    # Install dependencies
    apt-get update
    apt-get install -y \
        ca-certificates \
        curl \
        gnupg \
        lsb-release
    
    # Add Docker GPG key
    mkdir -p /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    
    # Add Docker repo
    echo \
        "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
        $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
    
    # Install Docker
    apt-get update
    apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    
    # Enable and start Docker
    systemctl enable docker
    systemctl start docker
    
    log_success "Docker installed successfully"
}

install_portainer() {
    log_info "Installing Portainer..."
    
    # Create Docker volume for Portainer
    docker volume create portainer_data 2>/dev/null || true
    
    # Run Portainer container
    docker run -d \
        --name portainer \
        --restart=always \
        -p 9443:9443 \
        -p 8000:8000 \
        --volume /var/run/docker.sock:/var/run/docker.sock \
        --volume portainer_data:/data \
        portainer/portainer-ce:latest
    
    log_success "Portainer installed at https://$(hostname -I | awk '{print $1}'):9443"
}

install_tailscale() {
    log_info "Installing Tailscale on host system..."
    
    # Check if Tailscale auth key is set
    if [[ -z "$TAILSCALE_AUTHKEY" ]]; then
        log_info "Tailscale requires an auth key for installation."
        log_info "To get an auth key, visit: https://login.tailscale.com/settings/key"
        log_info "Create a key with 'Reusable' and 'Auto-approval' enabled for easiest setup."
        echo ""
        read -p "Enter your Tailscale auth key (or press Enter to skip): " TAILSCALE_AUTHKEY
        echo ""
        
        if [[ -z "$TAILSCALE_AUTHKEY" ]]; then
            log_warn "Tailscale installation skipped - no auth key provided"
            return 1
        fi
    fi
    
    # Install Tailscale on the host
    curl -fsSL https://tailscale.com/install.sh | sh
    
    # Start Tailscale with auth key
    tailscale up --authkey="$TAILSCALE_AUTHKEY" --accept-routes
    
    log_success "Tailscale installed and connected"
    log_info "Check Tailscale status with: tailscale status"
    log_info "Manage Tailscale at: https://login.tailscale.com"
}

# Prompt for tailscale installation
prompt_tailscale() {
    echo ""
    log_info "Tailscale provides secure, passwordless SSH and site-to-site networking."
    log_info "It installs directly on the host and allows you to access your homelab from anywhere securely."
    log_info "It also enables route advertisement so other devices on your network can be accessed via Tailscale."
    echo ""
    
    if confirm "Would you like to install Tailscale?"; then
        install_tailscale
    else
        log_info "Tailscale installation skipped"
    fi
}

install_caddy() {
    log_info "Caddy reverse proxy disabled - services use direct ports"
    return 0
}

#######################################
# Dependency Management
#######################################

# Stage-based dependency ordering
# Services are installed in stages to ensure proper dependencies

# Stage 1: Core (prerequisites - always installed first)
STAGE1_CORE=("docker" "portainer" "tailscale")

# Stage 2: Authentication (Identity provider - early for auth needs)
STAGE2_AUTH=("keycloak")

# Stage 3: Media Automation (arr stack - base for media servers)
STAGE3_MEDIA_ARR=("sonarr" "radarr" "lidarr")

# Stage 4: Media Servers (require arr stack)
STAGE4_MEDIA_SERVERS=("jellyfin" "calibre" "navidrome" "immich")

# Stage 5: Request Management (needs arr stack)
STAGE5_REQUESTS=("jellyseerr")

# Stage 6: Dashboard (needs services running)
STAGE6_DASHBOARD=("homepage")

# Stage 7: Monitoring
STAGE7_MONITORING=("uptime-kuma" "grafana" "ntfy")

# Stage 8: Security (excludes keycloak - now in Stage 2)
STAGE8_SECURITY=("vaultwarden" "authelia" "adguard")

# Stage 9: Storage & Productivity
STAGE9_STORAGE=("nextcloud" "minio" "syncthing")

# Stage 10: AI
STAGE10_AI=("ollama" "openwebui")

# All stages in order
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

# Dependency graph: service -> services it depends on
declare -A DEPENDENCIES=(
    [jellyfin]="sonarr radarr"
    [jellyseerr]="sonarr radarr"
    # homepage has no dependencies in direct ports mode
)

# Resolve dependencies for a service
get_dependencies() {
    local service=$1
    local deps="${DEPENDENCIES[$service]}"
    echo "$deps"
}

# Check if a service is in a specific stage
service_in_stage() {
    local service=$1
    local stage_var=$2
    local stage_array=(${!stage_var})
    for s in "${stage_array[@]}"; do
        [[ "$s" == "$service" ]] && return 0
    done
    return 1
}

# Get stage for a service
get_service_stage() {
    local service=$1
    for stage in "${ALL_STAGES[@]}"; do
        local stage_array=(${!stage})
        for s in "${stage_array[@]}"; do
            [[ "$s" == "$service" ]] && echo "$stage" && return 0
        done
    done
    echo "STAGE_UNKNOWN"
}

# Sort services by dependency stage
sort_by_dependencies() {
    local services="$1"
    local sorted=""
    
    # Process each stage in order
    for stage in "${ALL_STAGES[@]}"; do
        local stage_array=(${!stage})
        for s in $services; do
            for stage_svc in "${stage_array[@]}"; do
                [[ "$s" == "$stage_svc" ]] && sorted="$sorted $s"
            done
        done
    done
    
    echo "$sorted"
}

log_stage() {
    local stage_num=$1
    local stage_name=$2
    echo ""
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}  STAGE $stage_num: $stage_name${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

#######################################
# Service Menu
#######################################

# Service definitions
declare -A SERVICES=(
    # Caddy disabled - services use direct ports
    ["jellyfin"]="Media server for movies, TV, and music"
    ["plex"]="Media server (requires paid license)"
    ["immich"]="Photo and video backup with AI"
    ["sonarr"]="TV show management"
    ["radarr"]="Movie management"
    ["lidarr"]="Music collection management"
    ["calibre"]="Ebook management and reader"
    ["navidrome"]="Music streaming server"
    ["jellyseerr"]="Request management for media"
    ["crafty"]="Minecraft server control panel"
    ["audiobookshelf"]="Audiobook server"
    ["tubearchivist"]="YouTube archive"
    ["adguard"]="DNS-level ad blocking"
    ["vaultwarden"]="Password manager"
    ["authelia"]="Two-factor authentication portal"
    ["keycloak"]="Identity and access management"
    ["uptime-kuma"]="Self-hosted monitoring"
    ["grafana"]="Metrics dashboards"
    ["prometheus"]="Metrics collection"
    ["ntfy"]="Push notifications"
    ["paperless"]="Document management"
    ["nextcloud"]="File sync and sharing"
    ["minio"]="S3-compatible storage"
    ["syncthing"]="File synchronization"
    ["ollama"]="Local AI models"
    ["openwebui"]="AI model web interface"
    ["homepage"]="Homelab dashboard"
)

show_service_menu() {
    clear
    echo -e "${BLUE}=======================================${NC}"
    echo -e "${BLUE}  HOMELAB SERVICE SELECTION${NC}"
    echo -e "${BLUE}=======================================${NC}"
    echo ""
    echo "Select services to install (space to toggle, enter to confirm)"
    echo ""
    
    # Group services by category
    echo -e "${YELLOW}📡 Networking${NC}"
    echo "  [ ] Caddy          - Reverse proxy (8080/8443)"
    echo "  [ ] AdGuard          - DNS-level ad blocking"
    echo ""
    echo -e "${YELLOW}🎬 Media${NC}"
    echo "  [ ] Jellyfin         - Media server (free)"
    echo "  [ ] Immich           - Photo & video backup (AI)"
    echo "  [ ] Calibre          - Ebook management"
    echo "  [ ] Navidrome        - Music streaming"
    echo "  [ ] Sonarr           - TV show management"
    echo "  [ ] Radarr           - Movie management"
    echo "  [ ] Lidarr           - Music collection"
    echo "  [ ] Jellyseerr       - Media requests"
    echo "  [ ] Audiobookshelf   - Audiobook server"
    echo ""
    echo -e "${YELLOW}🔐 Security${NC}"
    echo "  [ ] Vaultwarden      - Password manager"
    echo "  [ ] Authelia         - Two-factor authentication"
    echo "  [ ] Keycloak         - Identity & access management"
    echo ""
    echo -e "${YELLOW}📊 Monitoring${NC}"
    echo "  [ ] Uptime Kuma      - Self-hosted monitoring"
    echo "  [ ] Grafana          - Dashboards"
    echo "  [ ] ntfy             - Push notifications"
    echo ""
    echo -e "${YELLOW}📄 Productivity${NC}"
    echo "  [ ] Paperless        - Document management"
    echo "  [ ] Nextcloud        - File sync & sharing"
    echo ""
    echo -e "${YELLOW}💾 Storage${NC}"
    echo "  [ ] MinIO            - S3-compatible storage"
    echo "  [ ] Syncthing        - File synchronization"
    echo ""
    echo -e "${YELLOW}🤖 AI${NC}"
    echo "  [ ] Ollama           - Local AI models"
    echo "  [ ] OpenWebUI        - AI model web interface"
    echo ""
    echo -e "${YELLOW}🖥️ Dashboard${NC}"
    echo "  [ ] Homepage         - Homelab dashboard"
    echo ""
    echo -e "${GREEN}=======================================${NC}"
}

# Better interactive menu with checkbox-style selection
select_services() {
    clear
    echo -e "${BLUE}=======================================${NC}"
    echo -e "${BLUE}  HOMELAB SERVICE SELECTION${NC}"
    echo -e "${BLUE}=======================================${NC}"
    echo ""
    echo "Toggle services with numbers (space to toggle, enter to confirm)"
    echo ""
    
    # Define services with category
    declare -a SERVICES=(
        # Caddy disabled - services use direct ports
        "adguard:Networking:DNS-level ad blocking"
        "jellyfin:Media:Media server for movies, TV, and music"
        "immich:Media:Photo and video backup with AI"
        "calibre:Media:Ebook management and reader"
        "navidrome:Media:Music streaming server"
        "sonarr:Media:TV show management"
        "radarr:Media:Movie management"
        "lidarr:Media:Music collection management"
        "jellyseerr:Media:Media request management"
        "vaultwarden:Security:Password manager"
        "authelia:Security:Two-factor authentication portal"
        "keycloak:Security:Identity and access management"
        "uptime-kuma:Monitoring:Self-hosted monitoring"
        "grafana:Monitoring:Metrics dashboards"
        "ntfy:Monitoring:Push notifications"
        "nextcloud:Productivity:File sync and sharing"
        "paperless:Productivity:Document management"
        "minio:Storage:S3-compatible storage"
        "syncthing:Storage:File synchronization"
        "crafty:Games:Minecraft server control panel"
        "openclaw:AI:Homelab assistant / IT bot"
        "ollama:AI:Local AI models"
        "openwebui:AI:AI model web interface"
        "homepage:Dashboard:Homelab dashboard"
        "samba:Storage:Network file sharing"
    )
    
    # Initialize selection array
    declare -a SELECTED=()
    for i in "${!SERVICES[@]}"; do
        SELECTED[$i]=false
    done
    
    # Default selected services (recommended for most homelabs)
    # Caddy disabled - services use direct ports
    SELECTED[1]=true  # adguard (DNS for local .local domains)
    SELECTED[22]=true # homepage
    
    local running=true
    while $running; do
        clear
        echo -e "${BLUE}=======================================${NC}"
        echo -e "${BLUE}  HOMELAB SERVICE SELECTION${NC}"
        echo -e "${BLUE}=======================================${NC}"
        echo ""
        echo "Toggle services with numbers (a for all, d to confirm)"
        echo ""
        
        # Group by category
        local current_cat=""
        for i in "${!SERVICES[@]}"; do
            IFS=':' read -r key cat desc <<< "${SERVICES[$i]}"
            if [[ "$cat" != "$current_cat" ]]; then
                echo -e "${YELLOW}$cat${NC}"
                current_cat="$cat"
            fi
            local marker="[ ]"
            if [[ "${SELECTED[$i]}" == "true" ]]; then
                marker="${GREEN}[✓]${NC}"
            fi
            printf "  %2d) $marker %-15s - %s\n" "$i" "$key" "$desc"
        done
        
        echo ""
        echo -e "${GREEN}  d) DONE${NC}"
        echo ""
        read -p "Enter number to toggle (d to done): " choice
        
        if [[ "$choice" == "a" ]]; then
            for i in "${!SERVICES[@]}"; do
                SELECTED[$i]=true
            done
        elif [[ "$choice" == "d" ]]; then
            running=false
        elif [[ "$choice" =~ ^[0-9]+$ ]] && [[ "$choice" -lt "${#SERVICES[@]}" ]]; then
            if [[ "${SELECTED[$choice]}" == "true" ]]; then
                SELECTED[$choice]=false
            else
                SELECTED[$choice]=true
            fi
        else
            log_warn "Invalid selection"
            sleep 1
        fi
    done
    
    # Build selected services list
    SELECTED_SERVICES=""
    for i in "${!SERVICES[@]}"; do
        if [[ "${SELECTED[$i]}" == "true" ]]; then
            IFS=':' read -r key cat desc <<< "${SERVICES[$i]}"
            SELECTED_SERVICES="$SELECTED_SERVICES $key"
        fi
    done
    
    echo ""
    echo -e "${GREEN}Selected services:${NC}"
    for i in "${!SERVICES[@]}"; do
        if [[ "${SELECTED[$i]}" == "true" ]]; then
            IFS=':' read -r key cat desc <<< "${SERVICES[$i]}"
            echo "  - $key"
        fi
    done
}

#######################################
# Installation Mode Selection
#######################################

select_mode() {
    clear
    echo -e "${BLUE}=======================================${NC}"
    echo -e "${BLUE}  HOMELAB SETUP${NC}"
    echo -e "${BLUE}=======================================${NC}"
    echo ""
    echo "Select installation mode:"
    echo ""
    echo "  1. Simple (Docker + Portainer + Caddy) - Recommended"
    echo "  2. Advanced (K3s) - For experienced users"
    echo ""
    
    read -p "Enter choice [1]: " choice
    case "$choice" in
        2) 
            log_warn "Advanced mode not yet implemented"
            exit 1
            ;;
        *)
            MODE="simple"
            ;;
    esac
}

#######################################
# Main Installation Flow
#######################################

main() {
    echo ""
    echo -e "${GREEN}🚀 Homelab Installer${NC}"
    echo "========================"
    echo ""
    
    # Pre-flight checks
    check_root
    detect_os

    # Install Docker if needed
    if ! command -v docker &> /dev/null; then
        install_docker
    else
        log_info "Docker already installed"
    fi

    # Run pre-flight checks (docker group, port conflicts)
    preflight_checks

    # Create proxy network if needed
    if ! docker network inspect proxy >/dev/null 2>&1; then
        log_info "Creating proxy network..."
        docker network create proxy >/dev/null 2>&1 || true
        log_success "Proxy network created"
    else
        log_success "Proxy network exists"
    fi
    
    # Check for .env file
    if [ ! -f "$HOMELAB_DIR/.env" ]; then
        log_info ".env file not found. Creating with defaults..."
        cp "$HOMELAB_DIR/.env.example" "$HOMELAB_DIR/.env"
        
        # Auto-detect host IP and update .env if needed
        local detected_ip=$(auto_detect_ip)
        if [[ -z "$detected_ip" ]]; then
            log_warn "Could not auto-detect host IP address"
            read -p "Please enter your host's IP address: " detected_ip
        fi
        if grep -q "^IP=" "$HOMELAB_DIR/.env"; then
            sed -i "s/^IP=.*/IP=$detected_ip/" "$HOMELAB_DIR/.env"
        else
            echo "IP=$detected_ip" >> "$HOMELAB_DIR/.env"
        fi
        log_success "Host IP: $detected_ip"
    fi
    log_success ".env file exists"

    # Prompt for admin password first (required for validation)
    prompt_admin_password
    
    # Validate required environment variables
    validate_env_vars
    
    # Mode selection
    select_mode
    
    # Install base
    if ! command -v docker &> /dev/null; then
        install_docker
    else
        log_info "Docker already installed"
    fi
    
    # Install Portainer
    if ! docker ps -a | grep -q portainer; then
        install_portainer
    else
        log_info "Portainer already installed"
    fi
    
    # Prompt for Tailscale installation (after core services, before authentication)
    prompt_tailscale
    
    
    # Service selection
    echo ""
    if confirm "Would you like to select additional services?"; then
        select_services
        
        # Install services in dependency order
        if [[ -n "$SELECTED_SERVICES" ]]; then
            install_selected_services
        fi
    fi
    
    echo ""
    echo -e "${GREEN}=======================================${NC}"
    echo -e "${GREEN}  INSTALLATION COMPLETE!${NC}"
    echo -e "${GREEN}=======================================${NC}"
    echo ""
    local ip=$(hostname -I | awk '{print $1}')
    echo "📍 Access points:"
    echo "   - Portainer:  https://${ip}:9443"
    
    echo "Services are now accessible via direct ports on the host IP:"
    echo "   - Jellyfin:      http://${ip}:8096"
    echo "   - Sonarr:        http://${ip}:8989"
    echo "   - Radarr:        http://${ip}:7878"
    echo "   - Lidarr:        http://${ip}:6246"
    echo "   - Keycloak:      http://${ip}:8080"
    echo "   - Jellyseerr:    http://${ip}:5055"
    echo "   - Ollama:        http://${ip}:11434"
    echo "   - OpenWebUI:     http://${ip}:8080"
    echo "   - Grafana:       http://${ip}:3000"
    echo "   - Vaultwarden:   http://${ip}:8080"
    echo "   - Homepage:      http://${ip}:3000"
    echo "   - Authelia:      http://${ip}:9091"
    echo "   - AdGuard:       http://${ip}:3000"
    echo "   - Uptime Kuma:   http://${ip}:3001"
    echo "   - Nextcloud:     http://${ip}:8080"
    echo "   - MinIO:         http://${ip}:9000"
    echo "   - Syncthing:     http://${ip}:8384"
    echo "   - Paperless:     http://${ip}:8000"
    echo "   - Navidrome:     http://${ip}:4533"
    echo "   - Calibre:       http://${ip}:8080"
    echo "   - Audiobookshelf: http://${ip}:8081"
    echo "   - Immich:        http://${ip}:3000"
    echo "   - Authelia:      http://${ip}:9091"
    echo "   - Vaultwarden:   http://${ip}:8080"
    echo "   - Prometheus:    http://${ip}:9090"
    echo "   - ntfy:          http://${ip}:8080"
    declare -A SERVICE_PORTS=(
        [homepage]=3000
        [keycloak]=8080
        [jellyseerr]=5055
        [jellyfin]=8096
        [sonarr]=8989
        [radarr]=7878
        [ollama]=11434
        [openwebui]=8080
        [grafana]=3000
        [vaultwarden]=8080
    )
    
    # List running services with web interfaces
    for svc in ${!SERVICE_PORTS[@]}; do
        if docker ps --format '{{.Names}}' | grep -q "^$svc$"; then
            echo "   - ${svc}:      http://${ip}:${SERVICE_PORTS[$svc]}"
        fi
    done
    echo ""
    echo "📖 Next steps:"
    echo "   1. Accept Portainer SSL certificate (click Advanced → Proceed)"
    echo "   2. Create admin user on first login"
    echo "   3. Add more services from Portainer → Stacks"
    echo ""
}

#######################################
# Service Installation by Stage
#######################################

# Check if service is selected
is_service_selected() {
    local service=$1
    for s in $SELECTED_SERVICES; do
        [[ "$s" == "$service" ]] && return 0
    done
    return 1
}

# Install a single service from its compose file
install_service() {
    local service=$1
    local compose_file="$SERVICE_DIR/${service}.yml"
    
    # Skip if already installed (idempotent rerun)
    local current_state=$(get_service_state "$service")
    if [[ "$current_state" == installed_* ]]; then
        log_info "$service already installed (skipping)"
        return 0
    fi
    if [[ ! -f "$compose_file" ]]; then
        log_warn "No compose file for $service"
        return 1
    fi
    
    # Check if container exists - recreate to apply updated config
    if docker ps -a --format '{{.Names}}' | grep -q "^${service}$"; then
        log_info "Recreating $service with updated config..."
        docker rm -f "$service" >/dev/null 2>&1
    fi
    
    log_info "Installing $service..."
    
    # Create temp compose with variables expanded
    local temp_file=$(mktemp)
    env DOMAIN="${DOMAIN:-localhost}" HOMELAB_DIR="${HOMELAB_DIR}" envsubst < "$compose_file" > "$temp_file"
    
    # Run docker compose with  to clean up orphaned containers
    cd "$SERVICE_DIR"
    docker compose -f "$temp_file" up -d 
    
    rm -f "$temp_file"
    
    # Copy homepage config if it exists
    if [[ "$service" == "homepage" ]]; then
        if [[ -d "$CONFIG_DIR/homepage" ]]; then
            docker cp "$CONFIG_DIR/homepage/." homepage:/config/ 2>/dev/null
        fi
        # Add allowed hosts for direct IP access
        docker stop homepage >/dev/null 2>&1
        docker rm homepage >/dev/null 2>&1
        docker run -d --name homepage --network proxy -p 3000:3000             -e HOMEPAGE_ALLOWED_HOSTS=192.168.68.95:3000,localhost,home.${DOMAIN:-localhost}             -v homepage-config:/config             -v /var/run/docker.sock:/var/run/docker.sock:ro             ghcr.io/gethomepage/homepage:v1.0.4
    fi
    
    log_success "$service installed"
    update_service_state "$service" "installed_$(date -Iseconds)"
}

# Install services by stage
install_stage() {
    local stage_var=$1
    local stage_array=(${!stage_var})
    local stage_num=$2
    local stage_name=$3
    
    log_stage "$stage_num" "$stage_name"
    
    for service in "${stage_array[@]}"; do
        if is_service_selected "$service"; then
            # Check dependencies - auto-install missing ones
            local deps=$(get_dependencies "$service")
            if [[ -n "$deps" ]]; then
                for dep in $deps; do
                    if ! docker ps --format '{{.Names}}' | grep -q "^${dep}$"; then
                        log_info "Installing missing dependency: $dep"
                        install_service "$dep"
                    fi
                done
            fi
            
            install_service "$service"
        else
            log_info "Skipping $service (not selected)"
        fi
    done
}

# Main installation flow with stage-based ordering
install_selected_services() {
    echo ""
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}  INSTALLING SERVICES${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo -e "${YELLOW}Installing in dependency order...${NC}"
    echo ""
    
    
    # Stage 2: Auth (Keycloak)
    install_stage STAGE2_AUTH 2 "AUTHENTICATION"
    
    # Stage 3: Media ARR stack
    install_stage STAGE3_MEDIA_ARR 3 "MEDIA AUTOMATION (arr stack)"
    
    # Stage 4: Media servers
    install_stage STAGE4_MEDIA_SERVERS 4 "MEDIA SERVERS"
    
    # Stage 5: Request management
    install_stage STAGE5_REQUESTS 5 "REQUEST MANAGEMENT"
    
    # Stage 6: Dashboard
    install_stage STAGE6_DASHBOARD 6 "DASHBOARDS"
    
    # Stage 7: Monitoring
    install_stage STAGE7_MONITORING 7 "MONITORING"
    
    # Stage 8: Security
    install_stage STAGE8_SECURITY 8 "SECURITY"
    
    # Stage 9: Storage
    install_stage STAGE9_STORAGE 9 "STORAGE & PRODUCTIVITY"
    
    # Stage 10: AI
    install_stage STAGE10_AI 10 "AI SERVICES"
    
    echo ""
    echo -e "${GREEN}All selected services installed!${NC}"
}

# Run main
main "$@"
# State tracking for idempotent reruns
update_service_state() {
    local service=
    local status=
    
    # Create state file if it doesn't exist
    if [[ ! -f "" ]]; then
        echo '{"services": {}}' > ""
    fi
    
    # Update status using simple text file per service
    local state_dir="/.state"
    mkdir -p ""
    echo "" > "/"
}

get_service_state() {
    local service=
    local state_dir="/.state"
    if [[ -f "/" ]]; then
        cat "/"
    else
        echo "not_installed"
    fi
}

