# =============================================================================
# Import blocks for existing Authentik resources
# These are idempotent — TF skips import if resource is already in state.
# Remove this file once all imports are complete and plans show 0 changes.
# =============================================================================

# --- Groups ---
import {
  to = authentik_group.platform_admins
  id = "73d34026-62dc-4a30-9913-3b1add086fcc"
}
import {
  to = authentik_group.users
  id = "aa447aa5-b7fc-4643-94d0-b67afe16312a"
}
import {
  to = authentik_group.jellyfin_admins
  id = "ee1834a2-5d9f-4ae3-ba14-4635bbf2688a"
}
import {
  to = authentik_group.jellyfin_users
  id = "79f1d384-1dc8-48e1-873e-fc3f1e735c1f"
}

# --- Embedded Outpost (manages provider attachment) ---
import {
  to = authentik_outpost.embedded
  id = "17597b63-fb5e-4e99-9a97-d002e571d1bd"
}

# --- Additional Groups ---
# These will be created by TF if they don't exist, or imported if IDs are known.
# Run `terraform plan` first — if groups already exist, add import blocks with their UUIDs.
# To find UUIDs: curl -sk -H "Authorization: Bearer $TOKEN" https://auth.example.com/api/v3/core/groups/ | jq '.results[] | {name, pk}'

# --- Users ---
# Users will be created by TF if they don't exist, or imported if IDs are known.
# To find UUIDs: curl -sk -H "Authorization: Bearer $TOKEN" https://auth.example.com/api/v3/core/users/ | jq '.results[] | {username, pk}'
# After first plan, add import blocks here with the discovered UUIDs.

# --- OAuth2 Providers (pk integer) ---
import {
  to = authentik_provider_oauth2.apps["jellyfin"]
  id = "33"
}
import {
  to = authentik_provider_oauth2.apps["homarr"]
  id = "26"
}
import {
  to = authentik_provider_oauth2.apps["vaultwarden"]
  id = "4"
}
import {
  to = authentik_provider_oauth2.apps["amp"]
  id = "30"
}
import {
  to = authentik_provider_oauth2.apps["semaphore"]
  id = "3"
}
import {
  to = authentik_provider_oauth2.apps["gitlab"]
  id = "7"
}
import {
  to = authentik_provider_oauth2.apps["proxmox"]
  id = "38"
}
import {
  to = authentik_provider_oauth2.apps["netbox"]
  id = "6"
}
import {
  to = authentik_provider_oauth2.apps["headlamp"]
  id = "29"
}
import {
  to = authentik_provider_oauth2.apps["grafana"]
  id = "28"
}
import {
  to = authentik_provider_oauth2.apps["harbor"]
  id = "8"
}

# --- Proxy Providers (pk integer) ---
import {
  to = authentik_provider_proxy.apps["docmost"]
  id = "52"
}
import {
  to = authentik_provider_proxy.apps["adguard"]
  id = "55"
}
import {
  to = authentik_provider_proxy.apps["unifi"]
  id = "53"
}
import {
  to = authentik_provider_proxy.apps["traefik"]
  id = "56"
}
import {
  to = authentik_provider_proxy.apps["haproxy-stats"]
  id = "57"
}
import {
  to = authentik_provider_proxy.apps["vpn"]
  id = "48"
}
import {
  to = authentik_provider_proxy.apps["truenas"]
  id = "50"
}
import {
  to = authentik_provider_proxy.apps["seaweedfs"]
  id = "54"
}
import {
  to = authentik_provider_proxy.apps["prometheus"]
  id = "47"
}
import {
  to = authentik_provider_proxy.apps["alertmanager"]
  id = "51"
}
import {
  to = authentik_provider_proxy.apps["goldilocks"]
  id = "49"
}

# --- OAuth2 Applications (import by slug) ---
import {
  to = authentik_application.oauth2["jellyfin"]
  id = "jellyfin"
}
import {
  to = authentik_application.oauth2["homarr"]
  id = "homarr"
}
import {
  to = authentik_application.oauth2["vaultwarden"]
  id = "vaultwarden"
}
import {
  to = authentik_application.oauth2["amp"]
  id = "amp"
}
import {
  to = authentik_application.oauth2["semaphore"]
  id = "semaphore-sso"
}
import {
  to = authentik_application.oauth2["gitlab"]
  id = "gitlab"
}
import {
  to = authentik_application.oauth2["proxmox"]
  id = "proxmox"
}
import {
  to = authentik_application.oauth2["netbox"]
  id = "netbox"
}
import {
  to = authentik_application.oauth2["headlamp"]
  id = "kubernetes"
}
import {
  to = authentik_application.oauth2["grafana"]
  id = "grafana"
}
import {
  to = authentik_application.oauth2["harbor"]
  id = "harbor"
}

# --- Proxy Applications (import by slug) ---
import {
  to = authentik_application.proxy["docmost"]
  id = "docmost"
}
import {
  to = authentik_application.proxy["adguard"]
  id = "adguard"
}
import {
  to = authentik_application.proxy["unifi"]
  id = "unifi"
}
import {
  to = authentik_application.proxy["traefik"]
  id = "traefik-dashboard"
}
import {
  to = authentik_application.proxy["haproxy-stats"]
  id = "haproxy-stats"
}
import {
  to = authentik_application.proxy["vpn"]
  id = "vpn"
}
import {
  to = authentik_application.proxy["truenas"]
  id = "truenas"
}
import {
  to = authentik_application.proxy["seaweedfs"]
  id = "seaweedfs"
}
import {
  to = authentik_application.proxy["prometheus"]
  id = "prometheus"
}
import {
  to = authentik_application.proxy["alertmanager"]
  id = "alertmanager"
}
import {
  to = authentik_application.proxy["goldilocks"]
  id = "goldilocks"
}
