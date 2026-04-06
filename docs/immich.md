# Immich - Photo & Video Backup

Self-hosted photo and video backup solution with AI-powered features.

## Access

- **URL:** `https://immich.${DOMAIN:-localhost}`
- **Default Port:** `2283`

## First Setup

1. Open Immich in your browser
2. Create an admin account
3. Configure library paths:
   - Add `/photos` as your library location
   - Set up upload folders for backup
4. Install the mobile app for automatic backup

## Configuration

### Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `IMMICH_VERSION` | `release` | Immich version tag |
| `IMMICH_DB_PASSWORD` | `immich` | PostgreSQL password |
| `DOMAIN` | `localhost` | Traefik domain |

### Storage

- **Upload volume:** `immich-upload` - Temporary uploads
- **Photo mount:** `/mnt/photos` - Your photo library (read-only)
- **Database:** `immich-db` - PostgreSQL with vector extensions

## Features

- 📱 Mobile app for automatic backup
- 🔍 AI-powered search (faces, objects, clips)
- 🏷️ Albums and sharing
- 📤 External libraries support
- 🔄 Background encoding/transcoding
- 👤 User management

## Mobile App

Download the Immich mobile app:
- iOS: TestFlight (search "Immich")
- Android: APKs available on GitHub

## Backup

The database and uploads are stored in Docker volumes:
```bash
docker volume ls | grep immich
```

To back up:
```bash
docker run --rm -v immich-upload:/data -v $(pwd):/backup alpine tar czf /backup/immich-upload.tar.gz /data
docker run --rm -v immich-db:/data -v $(pwd):/backup alpine tar czf /backup/immich-db.tar.gz /data
```