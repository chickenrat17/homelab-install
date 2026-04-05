# Homepage

Modern homelab dashboard.

## Access

- URL: `https://home.<domain>`
- Default port: 3000

## Configuration

Configuration file: `services/homepage.yaml` → mounted to `/config`

### Example config.yaml

```yaml
---
logo:
  url: https://example.com/logo.png

header:
  - name: "My Homelab"
    icon: mdi:server

services:
  - name: "Media"
    icon: mdi:play-box-multiple
    items:
      - name: "Jellyfin"
        href: "https://jellyfin.example.com"
        icon: mdi:play-circle
      - name: "Sonarr"
        href: "https://sonarr.example.com"
        icon: mdi:television-classic

  - name: "Networking"
    icon: mdi:router-wireless
    items:
      - name: "AdGuard"
        href: "https://adguard.example.com"
        icon: mdi:shield-check
      - name: "Traefik"
        href: "http://traefik.localhost:8080"
        icon: mdi:router

  - name: "Monitoring"
    icon: mdi:chart-line
    items:
      - name: "Grafana"
        href: "https://grafana.example.com"
        icon: mdi:chart-box
      - name: "Uptime Kuma"
        href: "https://uptime.example.com"
        icon: mdi:clock-check
```

### Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `TZ` | America/Chicago | Timezone |

## Widgets

Homepage supports Docker, Prometheus, and many other widgets.