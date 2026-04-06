# Keycloak User Management

## Creating Users (Admin)

1. **Access Keycloak Admin Console**
   - Go to `https://keycloak.yourdomain.com`
   - Login with admin credentials

2. **Navigate to Users**
   - From the left menu: **Users** (under "Realm Management")

3. **Add a New User**
   - Click **Add User** (top right)
   - Fill in:
     - **Username**: e.g., `mikey`, `spouse`, `guest`
     - **Email**: user's email address
     - **First Name** / **Last Name**: optional
     - **Email Verified**: ON (or verify via email later)
   - Click **Save**

4. **Set Temporary Password**
   - After saving, go to the **Credentials** tab
   - Set a temporary password
   - Toggle **Temporary**: ON (forces password change on first login)

5. **Assign Roles (Optional)**
   - Go to **Role Mappings** tab
   - Assign roles like `admin`, `user`, or service-specific roles

6. **Inform User**
   - Send the temporary password to the user
   - They will be prompted to change it on first login

## User Login Flow

Users access protected services via:
- Direct URL (e.g., `https://vault.yourdomain.com`)
- Keycloak will redirect to login
- After login, they're redirected back to the service

## Service-Specific Access

Services with Keycloak auth in this stack:
- OpenClaw
- cAdvisor
- Prometheus
- Loki

Other services (Jellyfin, Vaultwarden, etc.) have their own auth — manage users directly in those services.

## Troubleshooting

**User can't login?**
- Check "Email Verified" is ON
- Check user is enabled (Users → select user → ensure "Enabled" is ON)
- Check correct realm (top-left dropdown should show "homelab")

**Forgot admin password?**
```bash
# Reset Keycloak admin via CLI
docker exec -it keycloak /opt/keycloak/bin/kc.sh set-password --realm master --user admin --new-password YOUR_NEW_PASSWORD
```