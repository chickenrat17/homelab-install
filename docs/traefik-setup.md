# Traefik Configuration

## Middleware Setup

The middleware config at `config/traefik-middleware.yml` needs to be loaded by Traefik's file provider.

### Option 1: Mount middleware file (recommended)

Add to your Traefik compose:

```yaml
volumes:
  - ./config/traefik-middleware.yml:/etc/traefik/dynamic/middleware.yml:ro
```

Then enable the file provider in Traefik config.

### Option 2: Inline labels

If file provider isn't set up, services can define their own middleware inline via labels. See existing services for examples.

## External Networks

All services share the `proxy` network. For internal-only services (like databases), create a separate internal network:

```yaml
networks:
  internal:
    driver: bridge
  proxy:
    external: true
```

Then only attach services that need external access to `proxy`.

## SSL/TLS

Traefik should be configured with Let's Encrypt or your own certificate. Update the Traefik compose with your email:

```yaml
certificatesResolvers:
  letsencrypt:
    acme:
      email: your-email@example.com
      storage: /letsencrypt/acme.json
      httpChallenge:
        entryPoint: web
```