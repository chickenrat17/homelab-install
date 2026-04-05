# Grafana

Metrics visualization and dashboards.

## Access

- URL: `https://grafana.<domain>`
- Default port: 3000 (internal)
- Default credentials: admin / admin

## First Setup

1. Login with default credentials
2. Change admin password
3. Add data sources (Prometheus, InfluxDB, etc.)

## Configuration

### Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `GF_SECURITY_ADMIN_USER` | admin | Admin username |
| `GF_SECURITY_ADMIN_PASSWORD` | admin | Admin password |
| `GF_INSTALL_PLUGINS` | - | Comma-separated plugin list |
| `TZ` | America/Chicago | Timezone |

## Dashboards

Popular dashboards:
- [Node Exporter](https://grafana.com/grafana/dashboards/1860) - System metrics
- [Docker Swarm](https://grafana.com/grafana/dashboards/10548) - Swarm metrics

## Volumes

- `grafana-data` - Dashboards and configuration