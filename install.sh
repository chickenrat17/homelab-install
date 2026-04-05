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
HOMELAB_DIR="$HOME/homelab-install"
SERVICE_DIR="$HOMELAB_DIR/services"
CONFIG_DIR="$HOMELAB_DIR/config"

#######################################
# Utility Functions
#######################################

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

install_traefik() {
    log_info "Installing Traefik..."
    
    # Create traefik directory
    mkdir -p "$CONFIG_DIR/traefik"
    
    # Create docker-compose.yml for Traefik
    cat > "$CONFIG_DIR/traefik/docker-compose.yml" << 'EOF'
version: '3.8'

services:
  traefik:
    image: traefik:v3.0
    container_name: traefik
    restart: unless-stopped
    security_opt:
      - no-new-privileges:true
    networks:
      - proxy
    ports:
      - "80:80"
      - "443:443"
      - "8080:8080"
    environment:
      - TZ=America/Chicago
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock:ro
      - $HOME/homelab-install/config/traefik/traefik.yml:/traefik.yml:ro
      - $HOME/homelab-install/config/traefik/acme.json:/acme.json
      - traefik-log:/logs
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.dashboard.rule=Host(`traefik.localhost`)"
      - "traefik.http.routers.dashboard.service=api@internal"

networks:
  proxy:
    name: proxy
    driver: bridge

volumes:
  traefik-log:
    name: traefik-log
EOF

    # Create traefik.yml config
    cat > "$CONFIG_DIR/traefik/traefik.yml" << 'EOF'
api:
  dashboard: true
  insecure: true

entryPoints:
  web:
    address: ":80"
    http:
      redirections:
        entryPoint:
          to: websecure
          scheme: https
  websecure:
    address: ":443"

providers:
  docker:
    endpoint: "unix:///var/run/docker.sock"
    exposedByDefault: false
    network: proxy
  file:
    directory: /etc/traefik/dynamic

log:
  level: INFO
  filePath: /logs/traefik.log

certificatesResolvers:
  letsencrypt:
    acme:
      email: admin@example.com
      storage: /acme.json
      httpChallenge:
        entryPoint: web
EOF

    # Set permissions
    touch "$CONFIG_DIR/traefik/acme.json"
    chmod 600 "$CONFIG_DIR/traefik/acme.json"
    
    # Create dynamic config directory
    mkdir -p "$CONFIG_DIR/traefik/dynamic"
    
    # Run Traefik
    cd "$CONFIG_DIR/traefik"
    docker compose up -d
    
    log_success "Traefik installed"
}

#######################################
# Service Menu
#######################################

# Service definitions
declare -A SERVICES=(
    ["traefik"]="Reverse proxy with automatic SSL"
    ["jellyfin"]="Media server for movies, TV, and music"
    ["plex"]="Media server (requires paid license)"
    ["sonarr"]="TV show management"
    ["radarr"]="Movie management"
    ["lidarr"]="Music collection management"
    ["jellyseerr"]="Request management for media"
    ["audiobookshelf"]="Audiobook server"
    ["tubearchivist"]="YouTube archive"
    ["adguard"]="DNS-level ad blocking"
    ["vaultwarden"]="Password manager"
    ["authelia"]="Two-factor authentication portal"
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
    echo "  [ ] Traefik          - Reverse proxy with automatic SSL"
    echo "  [ ] AdGuard          - DNS-level ad blocking"
    echo ""
    echo -e "${YELLOW}🎬 Media${NC}"
    echo "  [ ] Jellyfin         - Media server (free)"
    echo "  [ ] Sonarr           - TV show management"
    echo "  [ ] Radarr           - Movie management"
    echo "  [ ] Lidarr           - Music collection"
    echo "  [ ] Jellyseerr       - Media requests"
    echo "  [ ] Audiobookshelf   - Audiobook server"
    echo ""
    echo -e "${YELLOW}🔐 Security${NC}"
    echo "  [ ] Vaultwarden      - Password manager"
    echo "  [ ] Authelia         - Two-factor authentication"
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

# Simple menu using select
select_services() {
    local selected=()
    local options=("Traefik" "Jellyfin" "Sonarr" "Radarr" "Lidarr" "Jellyseerr" "Audiobookshelf" "AdGuard" "Vaultwarden" "Authelia" "Uptime Kuma" "Grafana" "ntfy" "Paperless" "Nextcloud" "MinIO" "Syncthing" "Ollama" "OpenWebUI" "Homepage")
    
    echo "Select services to install:"
    echo ""
    
    local PS3="Enter number to toggle (0 to done): "
    local result=""
    
    select service in "${options[@]}" "Done"; do
        case $service in
            "Done") break ;;
            "")
                log_warn "Invalid selection"
                ;;
            *)
                if [[ " ${selected[*]} " =~ " $service " ]]; then
                    selected=("${selected[@]/$service}")
                    log_info "Removed: $service"
                else
                    selected+=("$service")
                    log_info "Added: $service"
                fi
                ;;
        esac
    done
    
    echo ""
    echo "Selected services:"
    for s in "${selected[@]}"; do
        echo "  - $s"
    done
    
    SELECTED_SERVICES="${selected[*]}"
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
    echo "  1. Simple (Docker + Portainer + Traefik) - Recommended"
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
    
    # Install Traefik
    if ! docker ps -a | grep -q traefik; then
        install_traefik
    else
        log_info "Traefik already installed"
    fi
    
    # Service selection
    echo ""
    if confirm "Would you like to select additional services?"; then
        select_services
    fi
    
    echo ""
    echo -e "${GREEN}=======================================${NC}"
    echo -e "${GREEN}  INSTALLATION COMPLETE!${NC}"
    echo -e "${GREEN}=======================================${NC}"
    echo ""
    echo "📍 Access points:"
    echo "   - Portainer:  https://$(hostname -I | awk '{print $1}'):9443"
    echo "   - Traefik:    http://$(hostname -I | awk '{print $1}'):8080"
    echo ""
    echo "📖 Next steps:"
    echo "   1. Accept Portainer SSL certificate (click Advanced → Proceed)"
    echo "   2. Create admin user on first login"
    echo "   3. Add more services from Portainer → Stacks"
    echo ""
}

# Run main
main "$@"