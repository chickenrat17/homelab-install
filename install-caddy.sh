# Caddy Installer - Replaces Traefik with Caddy as reverse proxy

install_caddy() {
    log_info "Installing Caddy..."
    
    # Create caddy directory
    mkdir -p "$CONFIG_DIR/caddy"
    
    # Create docker-compose.yml for Caddy
    cat > "$CONFIG_DIR/caddy/docker-compose.yml" << 'EOF'
services:
  caddy:
    image: caddy:2
    container_name: caddy
    restart: unless-stopped
    ports:
      - "8080:80"
      - "8443:443"
    volumes:
      - $HOMELAB_DIR/config/caddy/Caddyfile:/etc/caddy/Caddyfile:ro
      - $HOMELAB_DIR/config/caddy/caddy-data:/data:rw
      - $HOMELAB_DIR/config/caddy/caddy-config:/config:rw
    networks:
      - proxy
    labels:
      - "traefik.enable=false"
    # Resource limits
    deploy:
      resources:
        limits:
          cpus: '0.2'
          memory: 256M

    healthcheck:
      test: ["CMD", "wget", "-q", "--spider", "http://localhost:2019/health"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 10s
    logging:
      driver: "json-file"
      options:
        max-size: "10m"
        max-file: "3"
networks:
  proxy:
    external: true
EOF

    # Create Caddyfile with all service routes
    cat > "$CONFIG_DIR/caddy/Caddyfile" << 'EOF'
# Caddyfile for Homelab Standalone
# Reverse proxy to services via container names on proxy network

{
    auto_https off
    log {
        level INFO
    }
}

# Homepage - main dashboard
http://localhost:8080 {
    reverse_proxy http://homepage:3000
}

# Traefik Dashboard (when available)
http://localhost:8090 {
    reverse_proxy http://traefik:8080
}

# PiHole Admin
http://localhost:8081 {
    reverse_proxy http://pihole:8081
}

# Jellyfin
http://localhost:8096 {
    reverse_proxy http://jellyfin:8096
}

# Keycloak
http://localhost:8080 {
    reverse_proxy http://keycloak:8080
}

# Nextcloud
http://localhost:8080 {
    reverse_proxy http://nextcloud:80
}

# Ollama
http://localhost:11434 {
    reverse_proxy http://ollama:11434
}

# Portainer
http://localhost:9443 {
    reverse_proxy http://portainer:9443
}

# Radarr
http://localhost:7878 {
    reverse_proxy http://radarr:7878
}

# Sonarr
http://localhost:8989 {
    reverse_proxy http://sonarr:8989
}

# Uptime Kuma
http://localhost:3001 {
    reverse_proxy http://uptime-kuma:3001
}

# Vaultwarden
http://localhost:8000 {
    reverse_proxy http://vaultwarden:8000
}
EOF

    # Start Caddy
    cd "$HOMELAB_DIR"
    docker compose -f "$CONFIG_DIR/caddy/docker-compose.yml" up -d
    
    # Wait for Caddy to be healthy
    for i in {1..30}; do
        if docker ps --format '{{.Names}}' | grep -q "^caddy$"; then
            if docker inspect --format '{{.State.Health.Status}}' caddy 2>/dev/null | grep -q "healthy"; then
                log_success "Caddy installed and healthy"
                return 0
            fi
        fi
        sleep 2
    done
    
    log_warn "Caddy installed but health check timed out"
}
