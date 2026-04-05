# ntfy

Push notifications service.

## Access

- URL: `https://ntfy.<domain>`
- Default port: 2586

## Usage

### Subscribe to topic

```bash
# Web
https://ntfy.example.com/mytopic

# ntfy app
ntfy.example.com/mytopic
```

### Publish from anywhere

```bash
# cURL
curl -d "Message text" ntfy.example.com/mytopic

# ntfy CLI
ntfy send -t mytopic "Hello"
```

## Configuration

### Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `TZ` | America/Chicago | Timezone |

## Auth

Enable basic auth in settings for private topics.