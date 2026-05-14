# =============================================================================
# Resource Pools - VM Organization
# bpg/proxmox resource: proxmox_virtual_environment_pool
# =============================================================================

resource "proxmox_virtual_environment_pool" "infrastructure" {
  pool_id = "infrastructure"
  comment = "Core infrastructure VMs (GitLab, Harbor, NetBox, HAProxy, AdGuard, CI Runner, AMP)"
}

resource "proxmox_virtual_environment_pool" "kubernetes" {
  pool_id = "kubernetes"
  comment = "Kubernetes cluster nodes (masters and workers)"
}

resource "proxmox_virtual_environment_pool" "services" {
  pool_id = "services"
}

# =============================================================================
# Pool Memberships - Assign VMs to pools
# Uses proxmox_virtual_environment_pool_membership (required attrs: pool_id, vm_id)
# =============================================================================

# Infrastructure pool members
resource "proxmox_virtual_environment_pool_membership" "adguard" {
  pool_id = proxmox_virtual_environment_pool.infrastructure.pool_id
  vm_id   = var.adguard_vm_id
}

resource "proxmox_virtual_environment_pool_membership" "harbor" {
  pool_id = proxmox_virtual_environment_pool.infrastructure.pool_id
  vm_id   = var.harbor_vm_id
}

resource "proxmox_virtual_environment_pool_membership" "gitlab" {
  pool_id = proxmox_virtual_environment_pool.infrastructure.pool_id
  vm_id   = var.gitlab_vm_id
}

resource "proxmox_virtual_environment_pool_membership" "netbox" {
  pool_id = proxmox_virtual_environment_pool.infrastructure.pool_id
  vm_id   = var.netbox_vm_id
}

resource "proxmox_virtual_environment_pool_membership" "haproxy_1" {
  pool_id = proxmox_virtual_environment_pool.infrastructure.pool_id
  vm_id   = 196 # haproxy-1
}

resource "proxmox_virtual_environment_pool_membership" "haproxy_2" {
  pool_id = proxmox_virtual_environment_pool.infrastructure.pool_id
  vm_id   = 197 # haproxy-2
}

resource "proxmox_virtual_environment_pool_membership" "ci_runner" {
  pool_id = proxmox_virtual_environment_pool.infrastructure.pool_id
  vm_id   = 105 # ci-runner
}

resource "proxmox_virtual_environment_pool_membership" "amp" {
  pool_id = proxmox_virtual_environment_pool.infrastructure.pool_id
  vm_id   = 117 # amp
}

# Kubernetes pool members
resource "proxmox_virtual_environment_pool_membership" "k8s_master_1" {
  pool_id = proxmox_virtual_environment_pool.kubernetes.pool_id
  vm_id   = 201 # k8s-master-1
}

resource "proxmox_virtual_environment_pool_membership" "k8s_master_2" {
  pool_id = proxmox_virtual_environment_pool.kubernetes.pool_id
  vm_id   = 202 # k8s-master-2
}

resource "proxmox_virtual_environment_pool_membership" "k8s_master_3" {
  pool_id = proxmox_virtual_environment_pool.kubernetes.pool_id
  vm_id   = 203 # k8s-master-3
}

resource "proxmox_virtual_environment_pool_membership" "k8s_worker_1" {
  pool_id = proxmox_virtual_environment_pool.kubernetes.pool_id
  vm_id   = 211 # k8s-worker-1 (GPU)
}

resource "proxmox_virtual_environment_pool_membership" "k8s_worker_2" {
  pool_id = proxmox_virtual_environment_pool.kubernetes.pool_id
  vm_id   = 212 # k8s-worker-2
}

resource "proxmox_virtual_environment_pool_membership" "k8s_worker_3" {
  pool_id = proxmox_virtual_environment_pool.kubernetes.pool_id
  vm_id   = 213 # k8s-worker-3
}

# Services pool members
resource "proxmox_virtual_environment_pool_membership" "vpn" {
  pool_id = proxmox_virtual_environment_pool.services.pool_id
  vm_id   = 110 # vpn
}


resource "proxmox_virtual_environment_pool_membership" "truenas" {
  pool_id = proxmox_virtual_environment_pool.services.pool_id
  vm_id   = 100 # truenas
}
