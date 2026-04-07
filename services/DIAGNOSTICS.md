# Service Diagnostics - homelab-install

## Goal
Systematically diagnose and fix all 31 services to ensure they are running and accessible

## Audience
Mikey Hall - Homelab administrator

## Output Paths
- Primary: ~/homelab-install/services/DIAGNOSTICS.md
- Notes: memory/2026-04-07.md

## Acceptance Criteria
- All services return 200 OK on web interfaces
- No containers in unhealthy/restarting state
- Services accessible via Traefik routing or direct ports

## Service Status Table

| Service | Status | Host Ports | Internal Port | Issue to Investigate |
|---------|--------|------------|---------------|---------------------|
| Traefik | Restarting (1) | - | 8080 | Volume mount issue - traefik.yml expected as file, not directory |
| Ollama | Unhealthy | 11434/tcp | 11434 | Container health check failing |
| Nextcloud | Healthy | 80/tcp | 80 | - |
| Vaultwarden | Unhealthy | 80/tcp | 80 | Container health check failing |
| UptimeKuma | Healthy | 3001/tcp | 3001 | - |
| Homepage | Healthy | 3000/tcp | 3000 | - |
| Jellyseerr | Up | 5055/tcp | 5055 | - |
| Jellyfin | Healthy | 8096/tcp | 8096 | - |
| Sonarr | Up | 8989/tcp | 8989 | - |
| Keycloak | Unhealthy | 8080/tcp | 8080 | Container health check failing |
| Ntfy | Restarting (0) | - | - | Config or port issue |
| HomeAssistant | Up | - | 8123 | Traefik only |
| Caddy | Up | 8090/80, 4443/443 | 80/443 | - |
| Cadvisor | Healthy | 8080/tcp | 8080 | - |
| OpenWebUI | Healthy | 8080/tcp | 8080 | - |
| OpenClaw | Health: Starting | - | - | Waiting for health check |
| Syncthing | Healthy | 8384/tcp | 8384 | - |
| Samba | Restarting (1) | - | 139/445 | Missing required parameters |
| Immich | Restarting (1) | - | 2283/3001 | Container health check failing |
| Immich DB | Healthy | 5432/tcp | 5432 | - |
| Immich Redis | Healthy | 6379/tcp | 6379 | - |
| Immich ML | Healthy | - | - | Traefik only |
| Paperless | Health: Starting | 8000/tcp | 8000 | Waiting for health check |
| Navidrome | Up | 4533/tcp | 4533 | - |
| Crafty | Up | 8443/tcp | 8443 | - |
| Calibre | Up | 8083/tcp | 8083 | - |
| Minio | Restarting (0) | - | 9000/9001 | Container health check failing |
| Lidarr | Up | 8686/tcp | 8686 | - |
| Pihole | Healthy | 8081/tcp | 80 | - |
| Grafana | Up | 3000/tcp | 3000 | - |
| Radarr | Up | 7878/tcp | 7878 | - |
| Portainer | Up | 8000/9443 | 8000/9443 | - |
| AdGuard | Up | - | 3000 | Traefik only (port 3010 externally) |

## Health Check URLs

Run these to verify service health:

```bash
# Test each service
curl -s -o /dev/null -w "%{http_code}" http://192.168.68.95:8090/dashboard/  # Traefik
curl -s -o /dev/null -w "%{http_code}" https://192.168.68.95:9443  # Portainer
curl -s -o /dev/null -w "%{http_code}" http://192.168.68.95:11434  # Ollama
curl -s -o /dev/null -w "%{http_code}" http://192.168.68.95:80  # Nextcloud, Vaultwarden
curl -s -o /dev/null -w "%{http_code}" http://192.168.68.95:3001  # UptimeKuma
curl -s -o /dev/null -w "%{http_code}" http://192.168.68.95:3000  # Homepage
curl -s -o /dev/null -w "%{http_code}" http://192.168.68.95:5055  # Jellyseerr
curl -s -o /dev/null -w "%{http_code}" http://192.168.68.95:8096  # Jellyfin
curl -s -o /dev/null -w "%{http_code}" http://192.168.68.95:8989  # Sonarr
curl -s -o /dev/null -w "%{http_code}" http://192.168.68.95:8080  # Keycloak, OpenWebUI
curl -s -o /dev/null -w "%{http_code}" http://192.168.68.95:8081  # Pihole
curl -s -o /dev/null -w "%{http_code}" http://192.168.68.95:8384  # Syncthing
curl -s -o /dev/null -w "%{http_code}" http://192.168.68.95:8090  # Caddy
curl -s -o /dev/null -w "%{http_code}" http://192.168.68.95:8080/metrics  # Cadvisor
curl -s -o /dev/null -w "%{http_code}" http://192.168.68.95:8000  # Paperless
curl -s -o /dev/null -w "%{http_code}" http://192.168.68.95:4533  # Navidrome
curl -s -o /dev/null -w "%{http_code}" http://192.168.68.95:8443  # Crafty
curl -s -o /dev/null -w "%{http_code}" http://192.168.68.95:8083  # Calibre
curl -s -o /dev/null -w "%{http_code}" http://192.168.68.95:8686  # Lidarr
curl -s -o /dev/null -w "%{http_code}" http://192.168.68.95:7878  # Radarr
curl -s -o /dev/null -w "%{http_code}" http://192.168.68.95:8000  # Portainer
```

## Services Requiring Immediate Attention

1. **Traefik** - Volume mount issue needs fixing
2. **Samba** - Missing required command parameters
3. **Ntfy** - Restarting, needs investigation
4. **Immich** - Container failing health checks
5. **Minio** - Container failing health checks
6. **Ollama, Vaultwarden, Keycloak** - Unhealthy status
7. **Samba, Immich Microservices** - Restarting

## Notes
- Services with Traefik only: AdGuard, Immich, Immich DB, Immich ML, Immich Redis, HomeAssistant, OpenClaw
- Port 3000 is used by Homepage (not Grafana)
- Port 3001 is used by UptimeKuma
