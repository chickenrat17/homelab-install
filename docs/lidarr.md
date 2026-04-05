# Lidarr

Music collection management.

## Access

- URL: `https://lidarr.<domain>`
- Default port: 8686

## First Setup

1. Navigate to Lidarr web interface
2. Go to Settings → Media Management
3. Add root folders for music
4. Configure download client

## Configuration

### Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `PUID` | 1000 | User ID for file ownership |
| `PGID` | 1000 | Group ID for file ownership |
| `TZ` | America/Chicago | Timezone |

## Volumes

- `lidarr-config` - Configuration and database