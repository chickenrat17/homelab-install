# Sonarr

TV show management and automation.

## Access

- URL: `https://sonarr.<domain>`
- Default port: 8989

## First Setup

1. Navigate to Sonarr web interface
2. Go to Settings → Media Management
3. Add root folders for TV shows
4. Configure download client (Radarr/Sabnzbd/Transmission)

## Configuration

### Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `PUID` | 1000 | User ID for file ownership |
| `PGID` | 1000 | Group ID for file ownership |
| `TZ` | America/Chicago | Timezone |

## Volumes

- `sonarr-config` - Configuration and database

## Download Client Integration

Recommended clients:
- SABnzbd
- NZBGet
- qBittorrent
- Transmission