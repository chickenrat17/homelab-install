#!/bin/bash
#
# Homelab Configure - Post-install service management
# Usage: bash ~/homelab-install/homelab-configure.sh
#

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Config
HOMELAB_DIR="$HOME/homelab-install"
SERVICE_DIR="$HOMELAB_DIR/services"
CONFIG_DIR="$HOMELAB_DIR/config"

# Available services
SERVICES=(
    "adguard:AdGuard Home - DNS-level ad blocking"
    "grafana:Grafana - Metrics visualization"
    "homepage:Homepage - Dashboard"
    "jellyfin:Jellyfin - Media server"
    "keycloak:Keycloak - Identity management"
    "lidarr:Lidarr - Music collection manager"
    "nextcloud:Nextcloud - File sync/share"
    "ntfy:Ntfy - Push notifications"
    "ollama:Ollama - Local LLM runtime"
    "openwebui:Open WebUI - ChatGPT-like UI for Ollama"
    "radarr:Radarr - Movie collection manager"
    "sonarr:Sonarr - TV series collection manager"
    "uptime-kuma:Uptime Kuma - Monitoring"
    "vaultwarden:Vaultwarden - Password manager"
)

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

# Check if Docker is running
check_docker() {
    if ! docker info &>/dev/null; then
        log_error "Docker is not running. Please run install.sh first."
        exit 1
    fi
}

# Check if a service is installed (container exists)
is_service_installed() {
    local service=$1
    docker ps -a --format '{{.Names}}' | grep -q "^${service}$"
}

# Check if service container is running
is_service_running() {
    local service=$1
    docker ps --format '{{.Names}}' | grep -q "^${service}$"
}

# Get service name from compose file
get_service_name() {
    local compose_file=$1
    basename "$compose_file" .yml
}

# Install a service
install_service() {
    local service=$1
    local compose_file="$SERVICE_DIR/${service}.yml"

    if [[ ! -f "$compose_file" ]]; then
        log_error "Compose file not found: $compose_file"
        return 1
    fi

    log_info "Installing $service..."

    # Create necessary directories
    mkdir -p "$CONFIG_DIR/$service"

    # Start the service
    cd "$HOMELAB_DIR"
    docker compose -f "$compose_file" up -d

    log_success "$service installed successfully"
}

# Remove a service
remove_service() {
    local service=$1
    local compose_file="$SERVICE_DIR/${service}.yml"

    log_warn "Removing $service..."

    if [[ -f "$compose_file" ]]; then
        cd "$HOMELAB_DIR"
        docker compose -f "$compose_file" down --volumes --remove-orphans 2>/dev/null || true
    fi

    log_success "$service removed"
}

# Get service description
get_service_desc() {
    local service=$1
    for s in "${SERVICES[@]}"; do
        if [[ "$s" == "$service:"* ]]; then
            echo "${s#*:}"
            return 0
        fi
    done
    echo "$service"
}

#######################################
# Menu Functions
#######################################

show_status() {
    echo ""
    echo "=========================================="
    echo "       HOMELAB SERVICE STATUS"
    echo "=========================================="
    echo ""

    local installed=() not_installed=()

    for s in "${SERVICES[@]}"; do
        service="${s%%:*}"
        if is_service_installed "$service"; then
            if is_service_running "$service"; then
                installed+=("  ${GREEN}●${NC} $service - $(get_service_desc $service)")
            else
                installed+=("  ${YELLOW}○${NC} $service - $(get_service_desc $service) (stopped)")
            fi
        else
            not_installed+=("  ${RED}○${NC} $service - $(get_service_desc $service)")
        fi
    done

    if [[ ${#installed[@]} -gt 0 ]]; then
        echo "${GREEN}INSTALLED SERVICES:${NC}"
        for item in "${installed[@]}"; do
            echo -e "$item"
        done
        echo ""
    fi

    if [[ ${#not_installed[@]} -gt 0 ]]; then
        echo "${RED}NOT INSTALLED:${NC}"
        for item in "${not_installed[@]}"; do
            echo -e "$item"
        done
    fi

    echo ""
}

get_installed_services() {
    local installed=()
    for s in "${SERVICES[@]}"; do
        service="${s%%:*}"
        if is_service_installed "$service"; then
            installed+=("$service")
        fi
    done
    echo "${installed[@]}"
}

get_available_services() {
    local available=()
    for s in "${SERVICES[@]}"; do
        service="${s%%:*}"
        if ! is_service_installed "$service"; then
            available+=("$service")
        fi
    done
    echo "${available[@]}"
}

prompt_install_service() {
    local available=$(get_available_services)
    if [[ -z "$available" ]]; then
        echo ""
        log_info "All services are already installed!"
        return
    fi

    echo ""
    echo "=========================================="
    echo "    AVAILABLE SERVICES TO INSTALL"
    echo "=========================================="
    echo ""

    local IFS=' '
    local options=($available)
    local n=1

    for service in "${options[@]}"; do
        echo "  $n) $(get_service_desc $service)"
        ((n++))
    done
    echo "  0) Back to main menu"
    echo ""

    read -p "Select service to install: " choice

    if [[ "$choice" == "0" || -z "$choice" ]]; then
        return
    fi

    if [[ "$choice" -ge 1 && "$choice" -le ${#options[@]} ]]; then
        local service="${options[$((choice-1))]}"
        echo ""
        log_info "Selected: $(get_service_desc $service)"
        
        if confirm "Install $service?"; then
            install_service "$service"
            log_success "$service is now running"
        fi
    else
        log_error "Invalid selection"
    fi
}

prompt_remove_service() {
    local installed=$(get_installed_services)
    if [[ -z "$installed" ]]; then
        echo ""
        log_info "No services installed yet."
        return
    fi

    echo ""
    echo "=========================================="
    echo "    INSTALLED SERVICES TO REMOVE"
    echo "=========================================="
    echo ""

    local IFS=' '
    local options=($installed)
    local n=1

    for service in "${options[@]}"; do
        local status=""
        if is_service_running "$service"; then
            status="${GREEN}(running)${NC}"
        else
            status="${YELLOW}(stopped)${NC}"
        fi
        echo "  $n) $service $status"
        ((n++))
    done
    echo "  0) Back to main menu"
    echo ""

    read -p "Select service to remove: " choice

    if [[ "$choice" == "0" || -z "$choice" ]]; then
        return
    fi

    if [[ "$choice" -ge 1 && "$choice" -le ${#options[@]} ]]; then
        local service="${options[$((choice-1))]}"
        echo ""
        
        if confirm "Remove $service? This will delete all data."; then
            remove_service "$service"
            log_success "$service has been removed"
        fi
    else
        log_error "Invalid selection"
    fi
}

prompt_stop_service() {
    local installed=$(get_installed_services)
    if [[ -z "$installed" ]]; then
        return
    fi

    echo ""
    echo "=========================================="
    echo "       STOP A RUNNING SERVICE"
    echo "=========================================="
    echo ""

    local IFS=' '
    local options=($installed)
    local n=1

    for service in "${options[@]}"; do
        if is_service_running "$service"; then
            echo "  $n) $service"
            ((n++))
        fi
    done
    echo "  0) Back to main menu"
    echo ""

    read -p "Select service to stop: " choice

    if [[ "$choice" == "0" || -z "$choice" ]]; then
        return
    fi

    if [[ "$choice" -ge 1 && "$choice" -le ${#options[@]} ]]; then
        local service="${options[$((choice-1))]}"
        if is_service_running "$service"; then
            docker stop "$service" &>/dev/null
            log_success "$service stopped"
        else
            log_warn "$service is not running"
        fi
    fi
}

prompt_start_service() {
    local installed=$(get_installed_services)
    if [[ -z "$installed" ]]; then
        return
    fi

    echo ""
    echo "=========================================="
    echo "       START A STOPPED SERVICE"
    echo "=========================================="
    echo ""

    local IFS=' '
    local options=($installed)
    local stopped=()

    for service in "${options[@]}"; do
        if ! is_service_running "$service"; then
            stopped+=("$service")
            echo "  ${#stopped[@]}) $service"
        fi
    done

    if [[ ${#stopped[@]} -eq 0 ]]; then
        log_info "All services are running"
        return
    fi

    echo "  0) Back to main menu"
    echo ""

    read -p "Select service to start: " choice

    if [[ "$choice" == "0" || -z "$choice" ]]; then
        return
    fi

    if [[ "$choice" -ge 1 && "$choice" -le ${#stopped[@]} ]]; then
        local service="${stopped[$((choice-1))]}"
        local compose_file="$SERVICE_DIR/${service}.yml"
        cd "$HOMELAB_DIR"
        docker compose -f "$compose_file" start
        log_success "$service started"
    fi
}

prompt_restart_service() {
    local installed=$(get_installed_services)
    if [[ -z "$installed" ]]; then
        return
    fi

    echo ""
    echo "=========================================="
    echo "       RESTART A SERVICE"
    echo "=========================================="
    echo ""

    local IFS=' '
    local options=($installed)
    local n=1

    for service in "${options[@]}"; do
        echo "  $n) $service"
        ((n++))
    done
    echo "  0) Back to main menu"
    echo ""

    read -p "Select service to restart: " choice

    if [[ "$choice" == "0" || -z "$choice" ]]; then
        return
    fi

    if [[ "$choice" -ge 1 && "$choice" -le ${#options[@]} ]]; then
        local service="${options[$((choice-1))]}"
        local compose_file="$SERVICE_DIR/${service}.yml"
        cd "$HOMELAB_DIR"
        docker compose -f "$compose_file" restart
        log_success "$service restarted"
    fi
}

main_menu() {
    while true; do
        show_status

        echo "=========================================="
        echo "          HOMELAB CONFIGURE"
        echo "=========================================="
        echo ""
        echo "  1) Install a new service"
        echo "  2) Remove an existing service"
        echo "  3) Start a stopped service"
        echo "  4) Stop a running service"
        echo "  5) Restart a service"
        echo "  6) View service logs"
        echo "  7) Open Portainer"
        echo "  8) Open Traefik Dashboard"
        echo ""
        echo "  0) Exit"
        echo ""

        read -p "Select option: " option

        case "$option" in
            1) prompt_install_service ;;
            2) prompt_remove_service ;;
            3) prompt_start_service ;;
            4) prompt_stop_service ;;
            5) prompt_restart_service ;;
            6)
                echo ""
                log_info "Checking running containers..."
                docker ps --format "table {{.Names}}\t{{.Status}}"
                echo ""
                read -p "Container name for logs (or Enter to skip): " container
                if [[ -n "$container" ]]; then
                    log_info "Showing logs for $container (Ctrl+C to exit)..."
                    docker logs -f --tail 50 "$container"
                fi
                ;;
            7)
                log_info "Opening Portainer..."
                echo ""
                echo "  URL: https://$(hostname -I | awk '{print $1}'):9443"
                echo ""
                ;;
            8)
                log_info "Traefik Dashboard..."
                echo ""
                echo "  URL: http://$(hostname -I | awk '{print $1}'):8080"
                echo ""
                ;;
            0)
                echo ""
                log_info "Goodbye!"
                exit 0
                ;;
            *)
                log_error "Invalid option"
                ;;
        esac

        echo ""
        read -p "Press Enter to continue..."
    done
}

#######################################
# Main
#######################################

main() {
    echo ""
    echo "=========================================="
    echo "     HOMELAB POST-INSTALL CONFIGURATOR"
    echo "=========================================="
    echo ""

    check_docker
    main_menu
}

main "$@"