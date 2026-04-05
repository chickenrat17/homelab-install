# Vaultwarden

Password manager.

## Access

- URL: `https://vault.<domain>`
- Default port: 80

## First Setup

1. Navigate to Vaultwarden web interface
2. Create your master password
3. Enable 2FA (recommended)

## Configuration

### Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `TZ` | America/Chicago | Timezone |

### Signups

By default, user signups are disabled. To enable:
1. Go to admin panel: `https://vault.<domain>/admin`
2. Enable signup settings

## Data

- All data stored in `vaultwarden-data` volume
- Export available in multiple formats