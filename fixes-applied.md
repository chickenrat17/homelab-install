# Fixes Applied to Homelab Installer

## Date: 2026-04-06

### 1. Traefik Dynamic Config Directory Fix
- Added `/etc/traefik/dynamic/middleware.yml` creation
- Added security headers middleware configuration

### 2. Homepage Allowed Hosts Fix
- Added `HOMEPAGE_ALLOWED_HOSTS` environment variable
- Includes IP, localhost, and domain variants

### 3. Traefik Dashboard Protection
- Added basic auth middleware for Traefik dashboard
- Created credentials file generation

### 4. Domain Validation
- Added validation for valid domain format
- Added warning for .local/.localtld domains

### 5. Service Health Checks
- Added healthcheck blocks to key services

### 6. Volume Cleanup
- Added orphaned volume cleanup before install

## Files Modified
- install.sh
- services/homepage.yml
- services/*.yml (various)

## Files Added
- config/traefik/dynamic/middleware.yml (template)
- .env.example (updated with comments)
