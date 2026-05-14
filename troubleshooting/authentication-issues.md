# Authentication Issues Troubleshooting Guide

## Overview

This guide covers SSO and authentication issues with Authentik, OIDC integrations, and service-specific authentication problems.

## Architecture

```
                    ┌┐
                           Authentik         
                      (Identity Provider)    
                     authentik.salt.saltstice
                    ┬┘
                                
        ┌┼┐
                                                    
   ┌▼┐  ┌▼┐  ┌▼┐  ┌▼┐  ┌▼┐
    Grafana   GitLab    Harbor    NetBox   Proxmox 
     OIDC      OIDC      OIDC      OIDC      OIDC  
   ┘  ┘  ┘  ┘  ┘
```

## Quick Reference

| Issue | Symptom | First Check |
|-------|---------|-------------|
| Can't login | Redirect loop | Authentik health |
| 401 Unauthorized | Invalid token | Token expiration |
| User not found | After SSO login | User provisioning |
| Wrong permissions | Access denied | Group mappings |

## Checking Authentik Health

```bash
# Check Authentik pods
kubectl get pods -n authentik

# Check Authentik health endpoint
curl -s https://auth.example.com/-/health/live/

# Check Authentik logs
kubectl logs -n authentik deployment/authentik-server --tail=100

# Check worker logs
kubectl logs -n authentik deployment/authentik-worker --tail=100
```

## Login Issues

### Cannot Login to Any Service

**Check Authentik is running**:

```bash
# Verify pods are healthy
kubectl get pods -n authentik

# Check if Authentik responds
curl -s https://auth.example.com/-/health/ready/

# If not responding, restart
kubectl rollout restart deployment/authentik-server -n authentik
```

**Check PostgreSQL database**:

```bash
# Check database pod
kubectl get pods -n authentik -l app=postgresql

# Check database connectivity
kubectl exec -it -n authentik deployment/authentik-server -- \
  python -c "from django.db import connection; connection.ensure_connection(); print('DB OK')"
```

**Check Redis cache**:

```bash
# Check Redis pod
kubectl get pods -n authentik -l app=redis

# Test Redis connectivity
kubectl exec -it -n authentik deployment/authentik-server -- \
  python -c "from django_redis import get_redis_connection; get_redis_connection().ping(); print('Redis OK')"
```

### Redirect Loop / Infinite Login

**Symptoms**:

- Page keeps redirecting
- "Too many redirects" error
- Login page reappears after login

**Diagnosis**:

```bash
# Check Traefik logs for the service
kubectl logs -n traefik deployment/traefik | grep <service>

# Check Authentik outpost logs
kubectl logs -n authentik deployment/authentik-proxy-outpost
```

**Common fixes**:

1. **Cookie domain mismatch**:
 - Make sure Authentik and service use same base domain
 - Check AUTHENTIK_COOKIE_DOMAIN setting

2. **HTTPS redirect loop**:
 - Make sure Traefik terminates SSL
 - Set X-Forwarded-Proto header correctly

3. **Session storage issue**:

   ```bash
   # Clear Redis cache
   kubectl exec -it -n authentik deployment/authentik-server -- \
     python -c "from django.core.cache import cache; cache.clear()"
   ```

### Invalid Credentials

```bash
# Check if user exists in Authentik
# Go to: Admin  Directory  Users

# Check user authentication source
# Local vs LDAP vs Social

# Reset password if needed
# Admin  Directory  Users  Select User  Set Password
```

## OIDC Integration Issues

### Service Can't Connect to Authentik

```bash
# Check OIDC discovery endpoint
curl -s https://auth.example.com/application/o/<provider>/.well-known/openid-configuration

# Verify provider exists in Authentik
# Admin  Applications  Providers

# Check client ID/secret match
# Compare service config with Authentik provider settings
```

### Token Validation Failed

**Symptoms**:

- 401 Unauthorized after login
- "Invalid token" errors
- "Token expired" errors

**Diagnosis**:

```bash
# Check time sync between services
date
kubectl exec -it -n <namespace> <pod> -- date

# Check token lifetime settings in Authentik
# Admin  Applications  Providers  <Provider>  Token Lifetime
```

**Fix time sync**:

```bash
# On VMs
timedatectl status
sudo timedatectl set-ntp true

# In containers, check if host time is correct
```

### User Not Created After Login

**Symptoms**:

- Login succeeds but user can't access service
- "User not found" in service

**Check Authentik user provisioning**:

```bash
# Verify user exists in Authentik
# Admin  Directory  Users

# Check OIDC claims being sent
# Admin  Applications  Providers  <Provider>  Preview
```

**Service-specific user creation**:

For **Grafana**:

```yaml
# Check auto_login and allow_sign_up settings
[auth.generic_oauth]
allow_sign_up = true
auto_login = true
```

For **GitLab**:

```ruby
# Check GitLab OIDC config
gitlab_rails['omniauth_allow_single_sign_on'] = ['openid_connect']
gitlab_rails['omniauth_auto_link_user'] = ['openid_connect']
```

For **Harbor**:

```bash
# Check OIDC auto-onboard setting
# Administration  Configuration  Authentication
# Auto Onboard should be enabled
```

## Group/Permission Issues

### Wrong Permissions After Login

**Symptoms**:

- User can login but lacks expected permissions
- Admin users appear as regular users

**Check Authentik groups**:

```bash
# Verify user group membership in Authentik
# Admin  Directory  Users  <User>  Groups

# Check group-to-role mapping in provider
# Admin  Applications  Providers  <Provider>  Scope Mapping
```

**Service group mapping**:

For **Grafana**:

```yaml
# Check role_attribute_path
[auth.generic_oauth]
role_attribute_path = contains(groups[*], 'grafana-admins') && 'Admin' || 'Viewer'
```

For **GitLab**:

```ruby
# Check groups_attribute
gitlab_rails['omniauth_providers'] = [
  {
    "name" => "openid_connect",
    "args" => {
      "groups_attribute" => "groups",
      "required_groups" => ["gitlab-users"]
    }
  }
]
```

## Service-Specific Issues

### Grafana OIDC

```bash
# Check Grafana OIDC config
kubectl get configmap -n monitoring grafana-config -o yaml

# Check Grafana logs
kubectl logs -n monitoring deployment/grafana | grep -i oauth

# Common issues:
# - Missing GF_AUTH_GENERIC_OAUTH_* environment variables
# - Wrong redirect URI (should be https://grafana.../login/generic_oauth)
```

### GitLab OIDC

```bash
# Check GitLab configuration
ssh gitlab "grep -A 30 omniauth /etc/gitlab/gitlab.rb"

# Check GitLab logs
ssh gitlab "gitlab-ctl tail gitlab-rails/production.log" | grep -i oauth

# Reconfigure after changes
ssh gitlab "gitlab-ctl reconfigure"
```

### Harbor OIDC

```bash
# Check Harbor OIDC configuration
# Administration  Configuration  Authentication

# Check Harbor logs
ssh harbor "docker-compose -f /opt/harbor/docker-compose.yml logs core" | grep -i oidc

# Common issues:
# - OIDC endpoint not reachable from Harbor VM
# - Client secret mismatch
```

### NetBox OIDC

```bash
# Check NetBox OIDC config
ssh netbox "cat /opt/netbox/netbox/configuration.py | grep -A 20 SOCIAL_AUTH"

# Check NetBox logs
ssh netbox "journalctl -u netbox | grep -i oauth"

# Restart after config changes
ssh netbox "systemctl restart netbox netbox-rq"
```

### Proxmox OIDC

```bash
# Check Proxmox realm configuration
ssh proxmox "cat /etc/pve/domains.cfg"

# Test OIDC connection
# Datacenter  Permissions  Realms  <OIDC Realm>  Test

# Common issues:
# - Certificate validation (need CA cert)
# - Username claim mismatch
```

## Authentik Administration

### Access Admin Interface

```
https://auth.example.com/if/admin/
```

### Reset Admin Password

```bash
# Exec into Authentik pod
kubectl exec -it -n authentik deployment/authentik-server -- bash

# Reset password
ak create_recovery_key 10 akadmin
# Use the generated recovery link
```

### Check Provider Configuration

```bash
# List all providers
# Admin  Applications  Providers

# For each OIDC provider, verify:
# - Client ID
# - Redirect URIs
# - Token lifetime
# - Scope mappings
```

## Debugging Commands

```bash
# Check Authentik events/audit log
# Admin  Events  Logs

# Check outpost status
kubectl get pods -n authentik -l app=authentik-proxy

# Check outpost logs
kubectl logs -n authentik -l app=authentik-proxy

# Test OIDC flow manually
# 1. Get authorization URL from provider
# 2. Visit URL in browser
# 3. Check for errors in Authentik logs
```

## Related Files

| File | Purpose |
|------|---------|
| `kubernetes/apps/authentik/` | Authentik deployment |
| `ansible/playbooks/23-authentik-configure-sso.yml` | SSO setup |
| `ansible/playbooks/24-configure-amp-oidc.yml` | AMP OIDC |
| `ansible/playbooks/25-configure-gitlab-oidc.yml` | GitLab OIDC |
| `ansible/playbooks/26-configure-harbor-oidc.yml` | Harbor OIDC |
| `ansible/playbooks/27-configure-netbox-oidc.yml` | NetBox OIDC |
| `ansible/playbooks/28-configure-proxmox-oidc.yml` | Proxmox OIDC |
