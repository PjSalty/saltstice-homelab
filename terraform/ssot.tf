# ==============================================================================
# SSOT Configuration - Read infrastructure settings from SSOT config files
# Per automation.md: All infrastructure config from config/network.yaml
# ==============================================================================

locals {
  # Read SSOT network configuration
  network_config = yamldecode(file("${path.module}/../config/network.yaml"))

  # VLAN shortcuts
  mgmt_vlan    = local.network_config.vlans.management
  infra_vlan   = local.network_config.vlans.infrastructure
  k8s_vlan     = local.network_config.vlans.kubernetes
  storage_vlan = local.network_config.vlans.storage
  dmz_vlan     = local.network_config.vlans.dmz

  # Gateway shortcuts
  mgmt_gateway    = local.mgmt_vlan.gateway
  infra_gateway   = local.infra_vlan.gateway
  k8s_gateway     = local.k8s_vlan.gateway
  storage_gateway = local.storage_vlan.gateway
  dmz_gateway     = local.dmz_vlan.gateway

  # DNS configuration
  dns_primary   = local.network_config.dns.primary
  dns_secondary = local.network_config.dns.secondary
  domain        = local.network_config.dns.internal_domain

  # Infrastructure static IPs from SSOT
  ssot_ips = {
    # Infrastructure VLAN
    gitlab    = local.infra_vlan.static_allocations.gitlab
    harbor    = local.infra_vlan.static_allocations.harbor
    netbox    = local.infra_vlan.static_allocations.netbox
    adguard   = local.infra_vlan.static_allocations.adguard
    haproxy_1 = local.infra_vlan.static_allocations.haproxy_01
    haproxy_2 = local.infra_vlan.static_allocations.haproxy_02
    semaphore = local.infra_vlan.static_allocations.semaphore
    amp       = local.infra_vlan.static_allocations.amp

    # Kubernetes VLAN
    k8s_master_1 = local.k8s_vlan.static_allocations.k8s_master_1
    k8s_master_2 = local.k8s_vlan.static_allocations.k8s_master_2
    k8s_master_3 = local.k8s_vlan.static_allocations.k8s_master_3
    k8s_worker_1 = local.k8s_vlan.static_allocations.k8s_worker_1
    k8s_worker_2 = local.k8s_vlan.static_allocations.k8s_worker_2
    k8s_worker_3 = local.k8s_vlan.static_allocations.k8s_worker_3

    # Storage VLAN
    truenas = local.storage_vlan.static_allocations.truenas

    # DMZ VLAN
    vpn = local.dmz_vlan.static_allocations.vpn
  }
}

# ==============================================================================
# SSOT-derived variables - Override defaults from SSOT
# ==============================================================================

# These variables can still be overridden via tfvars or CLI, but
# defaults come from SSOT config file

variable "use_ssot_config" {
  description = "Use SSOT config file for infrastructure settings"
  type        = bool
  default     = true
}
