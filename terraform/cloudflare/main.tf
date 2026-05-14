# =============================================================================
# Cloudflare Provider — DNS Records, Zone Settings
# =============================================================================
# v5 provider (ground-up rewrite from OpenAPI).
# Resource names changed in v5 (e.g. tunnel resources use zero_trust prefix,
# zone settings use cloudflare_zone_setting singular).
#
# Architecture note — public vs internal DNS:
#   PUBLIC  (Cloudflare): Only services NAT'd through the WAN IP
#           get Cloudflare DNS records. Currently: jellyfin (NAT WAN:<external-port> ->
#           Traefik:443) and the apex wildcard example.com.
#
#   INTERNAL (AdGuard → Traefik): All *.example.com services
#           (harbor, gitlab, auth, proxmox, netbox, grafana, etc.) resolve via
#           AdGuard DNS on the homelab to the Traefik MetalLB VIP. These are
#           NOT in Cloudflare — they are LAN-only and should never be publicly
#           reachable.
#
# The K8s cloudflare-dns-sync CronJob keeps the WAN A records current when
# the ISP changes the dynamic IP (annotated with dns.example.com/public=true).

terraform {
  required_version = ">= 1.0"
  required_providers {
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 5.0"
    }
  }
}

provider "cloudflare" {
  api_token = var.cloudflare_api_token
}

# =============================================================================
# Zone Data
# =============================================================================

data "cloudflare_zone" "main" {
  filter = {
    name = var.cloudflare_zone_name
  }
}

# Zero Trust Tunnel is managed by the cloudflared K8s Deployment
# (apps/cloudflared/) using a pre-created tunnel token from SOPS.
# API token scope is Zone:DNS only — tunnel management requires a
# separate Account:Tunnel:Edit token which we don't maintain in TF.

# =============================================================================
# Static DNS Records
# Only public-facing services that are NAT'd through the WAN are listed here.
# Internal services resolve via AdGuard → Traefik VIP (LAN only).
# The K8s cloudflare-dns-sync CronJob handles dynamic WAN IP updates.
# =============================================================================

resource "cloudflare_dns_record" "jellyfin" {
  zone_id = data.cloudflare_zone.main.id
  name    = "jellyfin"
  type    = "A"
  content = var.wan_ip
  ttl     = 300
  proxied = false # Proxying disabled: Jellyfin uses non-standard port <external-port>
}

# example.com — apex subdomain that acts as the homelab entry point.
# Points to the same WAN IP as jellyfin; resolved by Traefik based on SNI.
resource "cloudflare_dns_record" "salt" {
  zone_id = data.cloudflare_zone.main.id
  name    = "salt"
  type    = "A"
  content = var.wan_ip
  ttl     = 300
  proxied = false # Proxying disabled: internal Traefik handles TLS termination
}

# =============================================================================
# example.com apex — public personal site, served by GitHub Pages
# (PjSalty/saltstice-site → pjsalty.github.io with custom domain).
#
# GitHub Pages requires four apex A records pointing to its anycast IPs:
#   https://docs.github.com/en/pages/configuring-a-custom-domain-for-your-github-pages-site/managing-a-custom-domain-for-your-github-pages-site#configuring-an-apex-domain
#
# Cloudflare proxy is ON: edge caches static HTML, gives DDoS protection,
# and keeps the site responsive even when GH Pages has hiccups.
# =============================================================================

locals {
  github_pages_ips = [
    "185.199.108.153",
    "185.199.109.153",
    "185.199.110.153",
    "185.199.111.153",
  ]
}

resource "cloudflare_dns_record" "saltstice_apex" {
  for_each = toset(local.github_pages_ips)

  zone_id = data.cloudflare_zone.main.id
  name    = var.cloudflare_zone_name # apex
  type    = "A"
  content = each.value
  ttl     = 1 # 1 = "automatic" when proxied
  proxied = true
}

# www.example.com → apex (CNAME flattening via Cloudflare).
resource "cloudflare_dns_record" "saltstice_www" {
  zone_id = data.cloudflare_zone.main.id
  name    = "www"
  type    = "CNAME"
  content = "pjsalty.github.io"
  ttl     = 1
  proxied = true
}

# =============================================================================
# Zone Settings — SSL/TLS Hardening
# Applied to the example.com zone. These settings enforce encrypted
# connections and prevent downgrade attacks.
# =============================================================================

# Zone settings (ssl=full, min_tls_version=1.2, always_use_https=on) were
# previously managed by Terraform but are now unmanaged. The CI API token
# only has Zone:DNS:Edit scope; refresh PATCHes against zone settings 403,
# which fails the entire apply and blocks DNS work.
#
# `removed` blocks drop these from state without calling DELETE on the
# provider — the settings persist in Cloudflare unchanged. Re-import with
# a token that has Zone:Zone Settings:Edit if/when these need to be
# managed again.

removed {
  from = cloudflare_zone_setting.ssl
  lifecycle {
    destroy = false
  }
}

removed {
  from = cloudflare_zone_setting.min_tls_version
  lifecycle {
    destroy = false
  }
}

removed {
  from = cloudflare_zone_setting.always_use_https
  lifecycle {
    destroy = false
  }
}
