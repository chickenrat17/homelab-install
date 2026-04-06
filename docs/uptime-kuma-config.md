# Uptime Kuma Configuration

## Recommended Monitors

| Service | URL | Interval | Retry |
|---------|-----|----------|-------|
| Homepage | http://homepage:3000 | 60s | 3 |
| Keycloak | http://keycloak:8080/health | 60s | 3 |
| Vaultwarden | http://vaultwarden:80 | 60s | 3 |
| Home Assistant | http://homeassistant:8123 | 60s | 3 |
| Immich | http://immich:3001 | 60s | 3 |

## Notifications

Configure via Uptime Kuma UI after deployment:

1. **Telegram** (recommended for OpenClaw integration)
   - Bot Token: Get from @BotFather
   - Chat ID: Your Telegram chat ID

2. **Gotify** (self-hosted option)
   - URL: `https://ntfy.homelab.local`

3. **Email** (SMTP)
   - Use Vaultwarden's SMTP settings

## Alert Routing

- **Critical** (5 min down): Telegram to owner
- **Warning** (30 min down): Telegram + email

## OpenClaw Integration

OpenClaw can query Uptime Kuma API for status:
```bash
curl http://uptime-kuma:3001/api/status
```

Configure OpenClaw to check periodically and alert on service down.