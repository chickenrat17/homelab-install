# Radarr

Movie management and automation.

## Access

- URL: `https://radarr.<domain>`
- Default port: 7878

## First Setup

1. Navigate to Radarr web interface
2. Go to Settings → Media Management
3. Add root folders for movies
4. Configure download client

## Configuration

### Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `PUID` | 1000 | User ID for file ownership |
| `PGID` | 1000 | Group ID for file ownership |
| `TZ` | America/Chicago | Timezone |

## Volumes

- `radarr-config` - Configuration and database