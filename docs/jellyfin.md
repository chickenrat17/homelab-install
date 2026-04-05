# Jellyfin

Free and open-source media server for movies, TV shows, and music.

## Access

- URL: `https://jellyfin.<domain>`
- Default port: 8096

## First Setup

1. Navigate to the Jellyfin web interface
2. Create an admin user on first login
3. Add your media libraries pointing to `/media`

## Configuration

### Media Paths

| Path | Description |
|------|-------------|
| `/media/movies` | Movies |
| `/media/tv` | TV shows |
| `/media/music` | Music |

### Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `TZ` | America/Chicago | Timezone |

## Volumes

- `jellyfin-config` - Configuration files
- `jellyfin-cache` - Transcoding cache

## Traefik Labels

```yaml
- "traefik.http.routers.jellyfin.rule=Host(`jellyfin.<domain>`)"
- "traefik.http.routers.jellyfin.tls=true"
```