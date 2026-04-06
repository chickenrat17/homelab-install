# Calibre

Web interface for ebook management and reading.

## Access

- URL: `https://calibre.<domain>`
- Default port: 8083

## First Setup

1. Navigate to Calibre web interface
2. On first run, configure the library location:
   - Set `/books` as the library folder
3. Upload or connect your ebook collection

## Configuration

### Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `PUID` | 1000 | User ID for file ownership |
| `PGID` | 1000 | Group ID for file ownership |
| `TZ` | America/Chicago | Timezone |

## Volumes

- `calibre-config` - Application configuration
- `calibre-books` - Ebook library (connect to media folder)

## Usage Tips

- Calibre-web is a simplified web interface for Calibre
- For full Calibre features, use the desktop application
- Supports most ebook formats: epub, mobi, azw3, pdf, etc.