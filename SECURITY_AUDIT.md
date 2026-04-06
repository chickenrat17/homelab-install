# Homelab Installer Security Audit

**Date:** 2026-04-06  
**Auditor:** Carl (OpenClaw Coder Agent)

---

## Executive Summary

The homelab-install repository is **well-structured** but has **several security gaps** that should be fixed before pushing to main. The installer correctly uses Traefik for reverse proxying and Docker isolation, but there are issues with exposed ports, hardcoded credentials, and missing security headers in some services.

---

## 🔴 CRITICAL SECURITY ISSUES

### 1. **Hardcoded Default Passwords in .env.example**
**File:** `services/.env.example`  
**Issue:** Default passwords like `KEYCLOAK_ADMIN_PASSWORD=changeMe123!` are visible in the template  
**Risk:** If users don't change this, their Keycloak instance will use a weak default password  
**Fix:** Remove default values from .env.example, use comments only

```yaml
# Keycloak - MUST BE SET BY USER
# KEYCLOAK_ADMIN_PASSWORD=

# Grafana - MUST BE SET BY USER
# GF_SECURITY_ADMIN_PASSWORD=
```

### 2. **Traefik Dashboard Exposed Without Authentication**
**File:** `services/traefik.yml`  
**Issue:** Traefik dashboard is accessible at `traefik.localhost` with no auth middleware  
**Risk:** Unauthorized users could access service configurations  
**Fix:** Add basic auth middleware (already defined in middleware.yml template but not applied)

### 3. **Docker Socket Mounted Read-Only but Still Risky**
**Files:** `services/openclaw.yml`, `services/homeassistant.yml`, `services/homepage.yml`, `services/traefik.yml`  
**Issue:** `/var/run/docker.sock` grants container access to Docker daemon  
**Risk:** Container escape could lead to host compromise  
**Mitigation:** Already using `:ro` flag - good. Consider adding `--no-new-privileges:true` security option to all containers.

### 4. **SSH Keys Mounted in OpenClaw**
**File:** `services/openclaw.yml`  
**Issue:** `~/.ssh:/home/openclaw/.ssh:ro` mounts SSH keys  
**Risk:** If OpenClaw is compromised, SSH keys could be exfiltrated  
**Fix:** Only mount SSH keys if absolutely needed, use SSH agent forwarding instead

---

## 🟡 HIGH PRIORITY ISSUES

### 5. **Exposed Internal Ports for Services Behind Traefik**
**Files:** `services/jellyfin.yml`, `services/ollama.yml`  
**Issue:** Both services have `ports: "8096:8096"` and `"11434:11434"`  
**Risk:** These services are accessible directly via IP, bypassing Traefik  
**Fix:** Remove direct ports, rely on Traefik proxy only. If LAN access is needed, add a separate "internal" network.

### 6. **Missing Security Headers in Some Services**
**Affected Services:** `adguard.yml`, `calibre.yml`, `crafty.yml`, `immich.yml`, `jellyfin.yml`, `lidarr.yml`, `navidrome.yml`, `nextcloud.yml`, `radarr.yml`, `samba.yml`, `sonarr.yml`, `uptime-kuma.yml`, `vaultwarden.yml`  
**Issue:** These services don't have Traefik labels with security headers  
**Fix:** Add security headers middleware to all services

### 7. **Keycloak Using dev-file Database**
**File:** `services/keycloak.yml`  
**Issue:** `KC_DB=dev-file` is not suitable for production  
**Risk:** Data loss on container restart, not HA  
**Fix:** Use PostgreSQL or MariaDB for production deployments

### 8. **No Resource Limits on Containers**
**All services**  
**Issue:** No `mem_limit`, `cpus`, or `restart: unless-stopped` policies  
**Risk:** A misbehaving container could consume all host resources  
**Fix:** Add resource limits to all services

---

## 🟢 MEDIUM PRIORITY ISSUES

### 9. **Password in Environment Variables (Not Secrets)**
**Files:** All services with passwords  
**Issue:** Passwords stored in environment variables, not Docker secrets  
**Risk:** Visible in `docker inspect`, container logs  
**Fix:** Use Docker secrets or mounted files for sensitive data

### 10. **No Log Rotation Configured**
**All services**  
**Issue:** No logging driver configured, logs grow indefinitely  
**Fix:** Add logging configuration:
```yaml
logging:
  driver: "json-file"
  options:
    max-size: "10m"
    max-file: "3"
```

### 11. **Missing Health Checks on Many Services**
**Affected:** `adguard.yml`, `calibre.yml`, `crafty.yml`, `immich.yml`, `lidarr.yml`, `navidrome.yml`, `nextcloud.yml`, `radarr.yml`, `samba.yml`, `sonarr.yml`, `uptime-kuma.yml`, `vaultwarden.yml`  
**Fix:** Add health checks to all services (already added to homepage, jellyfin, ollama, traefik)

---

## 📋 RECOMMENDATIONS BEFORE PUSHING TO MAIN

1. **Update .env.example** - Remove default passwords
2. **Apply security headers** to all services
3. **Remove direct ports** for Traefik-managed services
4. **Add resource limits** to prevent resource exhaustion
5. **Add logging configuration** to all services
6. **Document SSH key risk** in README (or remove the mount)
7. **Add Keycloak database warning** in comments
8. **Consider removing SSH key mount** from OpenClaw

---

## ✅ POSITIVE FINDINGS

- Good use of Docker networks (proxy network隔离)
- Traefik correctly configured with HTTPS redirects
- Health checks added to critical services
- Domain validation added to install.sh
- Dynamic middleware configuration created
- Security headers middleware template included
- No API keys in code (all use environment variables)

---

## END OF AUDIT

**Next Steps:**
1. Fix critical issues (passwords, auth, exposed ports)
2. Add resource limits and logging
3. Test installation in clean environment
4. Run `openclaw doctor` equivalent check
5. Document security considerations in README
