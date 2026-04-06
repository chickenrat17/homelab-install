# Keycloak

Identity and Access Management (IAM) solution.

## Access

- URL: `https://keycloak.<domain>`
- Default port: 8080

## First Setup

1. Navigate to Keycloak admin console: `https://keycloak.<domain>/admin`
2. Login with default credentials:
   - Username: `admin`
   - Password: `changeMe123!`
3. Change the default admin password immediately
4. Create a new realm for your applications

## Configuration

### Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `TZ` | America/Chicago | Timezone |
| `KEYCLOAK_ADMIN` | admin | Initial admin username |
| `KEYCLOAK_ADMIN_PASSWORD` | changeMe123! | Initial admin password |
| `KC_DB` | dev-file | Database backend (dev-file, postgres, mysql) |

### Production Recommendations

1. Change the default admin credentials
2. Use a persistent database (PostgreSQL/MySQL) instead of file-based
3. Enable HTTPS in production
4. Configure realm-specific settings

## Data

- All data stored in `keycloak-data` volume
- Exports available via Keycloak admin console

## Integration

Keycloak can be used to secure other homelab services:
- Configure OpenID Connect (OIDC) in Traefik
- Use as authentication backend for web apps
- Integrate with Grafana, Jellyfin, Nextcloud, etc.