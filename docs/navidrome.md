# Navidrome

Modern music server and streamer with a beautiful web interface.

## Access

- URL: `https://music.<domain>`
- Default port: 4533

## First Setup

1. Navigate to Navidrome web interface
2. Create admin user on first login
3. Scan your music library

## Configuration

### Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `ND_PUID` | 1000 | User ID for file ownership |
| `ND_PGID` | 1000 | Group ID for file ownership |
| `TZ` | America/Chicago | Timezone |

## Volumes

- `navidrome-config` - Application configuration
- `navidrome-data` - Music cache and playlists

## Supported Clients

Navidrome works with many music streaming clients:

- **Web UI** - Built-in responsive player
- **Subsonic apps** - Compatible with all Subsonic clients
- **Airsonic** - Open source alternative
- **Sonixd** - Desktop client
- **Navidrome itself** - Mobile apps

## Features

- Supports MP3, FLAC, OGG, M4A, and more
- Transcoding on-the-fly
- Multi-user support with permissions
- Playlist management
- Star ratings and favorites
- Chromecast support