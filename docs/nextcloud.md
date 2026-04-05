# Nextcloud

File sync and sharing, collaboration platform.

## Access

- URL: `https://nextcloud.<domain>`
- Default port: 80

## First Setup

1. Navigate to Nextcloud web interface
2. Create admin account
3. Complete initial setup wizard

## Important Notes

- Requires significant storage for user files
- Consider adding external storage (SMB, NFS)
- Use Redis for caching (optional)

## Volumes

| Volume | Description |
|--------|-------------|
| `nextcloud-data` | User files |
| `nextcloud-apps` | Custom apps |
| `nextcloud-config` | Configuration |

## Recommended Add-ons

- OnlyOffice/Collabora for document editing
- External storage app for SMB/NFS mounts