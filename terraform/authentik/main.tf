# =============================================================================
# Authentik Provider — SSO Applications, OAuth2/Proxy Providers, Groups
# =============================================================================
# Replaces K8s Jobs: sso-complete-setup.yaml, semaphore-proxy-provider.yaml
# Authentik server/worker deployment remains in K8s (HelmRelease).

terraform {
  required_version = ">= 1.0"
  required_providers {
    authentik = {
      source  = "goauthentik/authentik"
      version = "~> 2025.0"
    }
  }
}

provider "authentik" {
  url   = var.authentik_url
  token = var.authentik_api_token
}

# =============================================================================
# Groups
# =============================================================================

resource "authentik_group" "platform_admins" {
  name         = "platform-admins"
  is_superuser = true
}

resource "authentik_group" "users" {
  name = "users"
}

resource "authentik_group" "jellyfin_admins" {
  name = "jellyfin-admins"
}

resource "authentik_group" "jellyfin_users" {
  name = "jellyfin-users"
}

# =============================================================================
# Users — declarative user management
# =============================================================================

locals {
  users = {
    salty = {
      username = "Salty"
      name     = "Salty"
      email    = "salty@example.com"
      is_admin = true
      groups   = ["platform_admins", "jellyfin_admins"]
    }
    alice = {
      username = "alice"
      name     = "Alice"
      email    = "alice@example.com"
      is_admin = false
      groups   = ["users", "jellyfin_users"]
    }
    bob = {
      username = "bob"
      name     = "Bob"
      email    = "bob@example.com"
      is_admin = false
      groups   = ["users", "jellyfin_users"]
    }
    carol = {
      username = "carol"
      name     = "Carol"
      email    = "carol@example.com"
      is_admin = false
      groups   = ["users", "jellyfin_users"]
    }
    dave = {
      username = "dave"
      name     = "Dave"
      email    = "dave@example.com"
      is_admin = false
      groups   = ["users", "jellyfin_users"]
    }
    eve = {
      username = "eve"
      name     = "Eve"
      email    = "eve@example.com"
      is_admin = false
      groups   = ["users", "jellyfin_users"]
    }
  }

  # Map group key -> resource ID for user group assignment
  group_ids = {
    platform_admins = authentik_group.platform_admins.id
    users           = authentik_group.users.id
    jellyfin_admins = authentik_group.jellyfin_admins.id
    jellyfin_users  = authentik_group.jellyfin_users.id
  }
}

resource "authentik_user" "users" {
  for_each = local.users

  username = each.value.username
  name     = each.value.name
  email    = each.value.email
  password = lookup(var.user_passwords, each.key, null)
  groups   = [for g in each.value.groups : local.group_ids[g]]

  lifecycle {
    prevent_destroy = true
    # Password changes in Authentik UI shouldn't trigger TF drift
    ignore_changes = [password]
  }
}

# =============================================================================
# Certificate & Signing Key (for OAuth2 providers)
# =============================================================================

data "authentik_certificate_key_pair" "default" {
  name = "authentik Self-signed Certificate"
}

data "authentik_flow" "default_authorization" {
  slug = "default-provider-authorization-implicit-consent"
}

data "authentik_flow" "default_invalidation" {
  slug = "default-provider-invalidation-flow"
}

data "authentik_property_mapping_provider_scope" "openid" {
  managed_list = [
    "goauthentik.io/providers/oauth2/scope-openid",
    "goauthentik.io/providers/oauth2/scope-profile",
    "goauthentik.io/providers/oauth2/scope-email",
  ]
}

# =============================================================================
# OAuth2 Providers (native OIDC applications)
# =============================================================================

locals {
  oauth2_apps = {
    jellyfin = {
      name          = "Jellyfin"
      client_id     = "jellyfin-sso"
      redirect_uris = ["https://jellyfin.example.com/sso/OID/redirect/authentik"]
      launch_url    = "https://jellyfin.example.com"
    }
    homarr = {
      name          = "Homarr"
      client_id     = "homarr-sso"
      redirect_uris = ["https://home.example.com/api/auth/callback/oidc"]
      launch_url    = "https://home.example.com"
    }
    vaultwarden = {
      name          = "Vaultwarden"
      client_id     = "vaultwarden-sso"
      redirect_uris = ["https://vault.example.com/identity/connect/oidc-signin"]
      launch_url    = "https://vault.example.com"
    }
    amp = {
      name          = "AMP"
      client_id     = "amp-sso"
      redirect_uris = ["https://amp.example.com/"]
      launch_url    = "https://amp.example.com"
    }
    semaphore = {
      name          = "Semaphore"
      client_id     = "semaphore-sso"
      redirect_uris = ["https://semaphore.example.com/api/auth/oidc/authentik/redirect"]
      launch_url    = "https://semaphore.example.com"
    }
    gitlab = {
      name          = "GitLab"
      client_id     = "gitlab-sso"
      redirect_uris = ["https://gitlab.example.com/users/auth/openid_connect/callback"]
      launch_url    = "https://gitlab.example.com"
    }
    proxmox = {
      name          = "Proxmox VE"
      client_id     = "proxmox-sso"
      redirect_uris = ["https://proxmox.example.com:8006", "https://<mgmt-ip>:8006"]
      launch_url    = "https://proxmox.example.com:8006"
    }
    netbox = {
      name          = "NetBox"
      client_id     = "netbox-sso"
      redirect_uris = ["https://netbox.example.com/oauth/complete/oidc/"]
      launch_url    = "https://netbox.example.com"
    }
    headlamp = {
      name          = "Headlamp"
      client_id     = "kubernetes"
      redirect_uris = ["https://k8s.example.com/oidc-callback"]
      launch_url    = "https://k8s.example.com"
    }
    grafana = {
      name          = "Grafana"
      client_id     = "grafana-sso"
      redirect_uris = ["https://grafana.example.com/login/generic_oauth"]
      launch_url    = "https://grafana.example.com"
    }
    harbor = {
      name          = "Harbor"
      client_id     = "harbor-sso"
      redirect_uris = ["https://harbor.example.com/c/oidc/callback"]
      launch_url    = "https://harbor.example.com"
    }
  }
}

resource "authentik_provider_oauth2" "apps" {
  for_each = local.oauth2_apps

  name               = each.value.name
  client_id          = each.value.client_id
  client_secret      = lookup(var.oauth2_client_secrets, each.key, null)
  authorization_flow = data.authentik_flow.default_authorization.id
  invalidation_flow  = data.authentik_flow.default_invalidation.id
  signing_key        = data.authentik_certificate_key_pair.default.id

  allowed_redirect_uris = [
    for uri in each.value.redirect_uris : {
      matching_mode = "strict"
      url           = uri
    }
  ]

  property_mappings = data.authentik_property_mapping_provider_scope.openid.ids

  lifecycle {
    prevent_destroy = true
  }
}

resource "authentik_application" "oauth2" {
  for_each = local.oauth2_apps

  name              = each.value.name
  slug              = each.key
  protocol_provider = authentik_provider_oauth2.apps[each.key].id
  meta_launch_url   = each.value.launch_url
  open_in_new_tab   = true
}

# =============================================================================
# Policies — password strength, expiry, brute-force protection, access control
# =============================================================================

# Enforce strong passwords globally
resource "authentik_policy_password" "global" {
  name             = "global-password-policy"
  length_min       = 12
  amount_uppercase = 1
  amount_lowercase = 1
  amount_digits    = 1
  amount_symbols   = 0
  error_message    = "Password must be at least 12 characters with uppercase, lowercase, and digits"
}

# Require admin accounts to rotate passwords every 90 days
resource "authentik_policy_expiry" "admin_password_expiry" {
  name      = "admin-password-expiry"
  days      = 90
  deny_only = false
}

# Block brute-force attacks via IP and username reputation scoring
resource "authentik_policy_reputation" "anti_bruteforce" {
  name           = "anti-bruteforce"
  check_ip       = true
  check_username = true
  threshold      = -5
}

# Restrict sensitive infrastructure apps to superusers or platform-admins group
resource "authentik_policy_expression" "admin_only" {
  name       = "admin-only-access"
  expression = "return request.user.is_superuser or ak_is_group_member(request.user, name='platform-admins')"
}

# =============================================================================
# Policy Bindings — apply admin-only policy to sensitive infrastructure apps
# =============================================================================

resource "authentik_policy_binding" "admin_proxmox" {
  target = authentik_application.oauth2["proxmox"].uuid
  policy = authentik_policy_expression.admin_only.id
  order  = 0
}

resource "authentik_policy_binding" "admin_traefik" {
  target = authentik_application.proxy["traefik"].uuid
  policy = authentik_policy_expression.admin_only.id
  order  = 0
}

resource "authentik_policy_binding" "admin_prometheus" {
  target = authentik_application.proxy["prometheus"].uuid
  policy = authentik_policy_expression.admin_only.id
  order  = 0
}

resource "authentik_policy_binding" "admin_alertmanager" {
  target = authentik_application.proxy["alertmanager"].uuid
  policy = authentik_policy_expression.admin_only.id
  order  = 0
}

# =============================================================================
# Proxy Providers (forward-auth via Traefik middleware)
# =============================================================================

locals {
  proxy_apps = {
    docmost       = { name = "Docmost", url = "https://docs.example.com" }
    adguard       = { name = "AdGuard Home", url = "https://adguard.example.com" }
    unifi         = { name = "UniFi", url = "https://unifi.example.com" }
    traefik       = { name = "Traefik Dashboard", url = "https://traefik.example.com" }
    haproxy-stats = { name = "HAProxy Stats", url = "https://haproxy.example.com" }
    vpn           = { name = "WireGuard VPN", url = "https://vpn.example.com" }
    truenas       = { name = "TrueNAS", url = "https://truenas.example.com" }
    seaweedfs     = { name = "SeaweedFS", url = "https://seaweedfs.example.com" }
    prometheus    = { name = "Prometheus", url = "https://prometheus.example.com" }
    alertmanager  = { name = "AlertManager", url = "https://alerts.example.com" }
    goldilocks    = { name = "Goldilocks", url = "https://goldilocks.example.com" }
    headlamp-fwd  = { name = "Headlamp Forward Auth", url = "https://k8s.example.com" }
  }
}

resource "authentik_provider_proxy" "apps" {
  for_each = local.proxy_apps

  name               = each.value.name
  external_host      = each.value.url
  mode               = "forward_single"
  authorization_flow = data.authentik_flow.default_authorization.id
  invalidation_flow  = data.authentik_flow.default_invalidation.id

  lifecycle {
    prevent_destroy = true
  }
}

resource "authentik_application" "proxy" {
  for_each = local.proxy_apps

  name              = each.value.name
  slug              = each.key
  protocol_provider = authentik_provider_proxy.apps[each.key].id
  meta_launch_url   = each.value.url
  open_in_new_tab   = true
}

# =============================================================================
# Embedded Outpost — manages which proxy providers Traefik forward-auth resolves
# =============================================================================
# All TF-managed proxy providers are attached automatically. Legacy forward-auth
# providers (no application binding) are kept for backward compatibility until
# they can be cleaned up.

locals {
  legacy_forward_auth_provider_ids = [
    34, # AdGuard Forward Auth (orphan)
    35, # UniFi Forward Auth (orphan)
    36, # TrueNAS Forward Auth (orphan)
  ]
}

data "authentik_service_connection_kubernetes" "local" {
  name = "Local Kubernetes Cluster"
}

resource "authentik_outpost" "embedded" {
  name               = "authentik Embedded Outpost"
  type               = "proxy"
  service_connection = data.authentik_service_connection_kubernetes.local.id
  protocol_providers = concat(
    [for k, p in authentik_provider_proxy.apps : p.id],
    local.legacy_forward_auth_provider_ids,
  )
  config = jsonencode({
    log_level               = "info"
    authentik_host          = "https://auth.example.com"
    authentik_host_browser  = "https://auth.example.com"
    authentik_host_insecure = false
    kubernetes_replicas     = 1
    kubernetes_namespace    = "authentik"
    container_image         = null
  })
}
