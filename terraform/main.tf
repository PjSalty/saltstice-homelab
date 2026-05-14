# =============================================================================
# Terraform Main Configuration - BPG Provider for GPU Passthrough Support
# Provider version synced with config/versions.yaml SSOT (validated 2025-12-14)
# Pipeline trigger: 2025-12-15 15:48 - Fix SOPS key handling in deploy:amp
# =============================================================================

terraform {
  required_version = ">= 1.0"
  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "~> 0.106.0" # Per config/versions.yaml SSOT
    }
  }
}

provider "proxmox" {
  endpoint = "https://${var.proxmox_host}:8006/"
  # Use API token authentication
  api_token = "${var.proxmox_user}=${var.proxmox_password}"
  insecure  = var.proxmox_tls_insecure # Configure in tfvars (false = verify TLS, true = skip verification)

  ssh {
    agent    = false
    username = "root"

    # Map node name to IP address for SSH connections
    node {
      name    = var.proxmox_node
      address = var.proxmox_host
    }
  }
}

# =============================================================================
# Infrastructure VMs - TrueNAS Central Storage
# =============================================================================

resource "proxmox_virtual_environment_vm" "truenas" {
  name        = "truenas"
  description = "Phase 0 - Central Storage (ZFS + NFS + MinIO S3)"
  tags        = ["infrastructure", "storage", "truenas", "zfs", "nfs", "s3", "phase0"]
  node_name   = var.proxmox_node
  vm_id       = 100

  machine = "q35" # Modern machine type for better I/O

  clone {
    vm_id = 9000 # Debian 13 cloud template
    full  = true
  }

  agent {
    enabled = false
    timeout = "5s"
  }

  cpu {
    cores = 4 # Actual: 4 cores
    type  = "host"
  }

  memory {
    dedicated = 32768 # Actual: 32GB
  }

  # OS disk on local-zfs (scsi0)
  disk {
    datastore_id = "local-zfs"
    interface    = "scsi0"
    size         = 128
    iothread     = true
  }

  # Dynamic passthrough of discovered 6TB data disks (scsi1-scsi12)
  # Populated from truenas_disks.auto.tfvars (auto-discovered via WWN)
  # Uses raw block device passthrough: datastore_id="" + path_in_datastore + file_format="raw"
  # Reference: https://github.com/bpg/terraform-provider-proxmox/blob/main/docs/resources/virtual_environment_vm.md
  dynamic "disk" {
    for_each = var.truenas_data_disks
    content {
      interface         = "scsi${disk.key + 1}"
      datastore_id      = ""         # Empty for raw device passthrough
      path_in_datastore = disk.value # /dev/disk/by-id/wwn-*
      file_format       = "raw"      # Raw block device
      iothread          = true
      discard           = "on"
      cache             = "none" # Required for raw block devices
    }
  }

  # Management network (vmbr1, no VLAN tag)
  network_device {
    bridge = "vmbr1"
    model  = "virtio"
  }

  # Storage network (vmbr1, VLAN 40)
  network_device {
    bridge  = "vmbr1"
    model   = "virtio"
    vlan_id = 40
  }

  operating_system {
    type = "l26"
  }

  initialization {
    datastore_id = "local-zfs"

    ip_config {
      ipv4 {
        address = "${var.truenas_ip}/24"
        gateway = var.gateway
      }
    }

    user_account {
      username = "debian"
      keys     = [var.ssh_public_key]
    }

    dns {
      servers = [var.dns_primary]
    }
  }

  vga {
    type = "std"
  }

  # TrueNAS depends on AdGuard for DNS resolution during setup
  depends_on = [module.adguard]

  lifecycle {
    prevent_destroy = true
    # Ignore attributes managed outside Terraform (TrueNAS is complex)
    ignore_changes = [
      clone,
      initialization,
      cdrom,
      started,
      agent,
      bios,     # TrueNAS uses OVMF (UEFI)
      efi_disk, # EFI disk managed by Proxmox
      serial_device,
      startup,
      rng,  # RNG device
      disk, # Disk config is complex with passthrough
      scsi_hardware,
      tags,           # Tags may be reordered
      description,    # Description may differ
      network_device, # Network config may have extra NICs
    ]
  }
}

# =============================================================================
# AdGuard Home DNS Server - FIRST in bootstrap order
# =============================================================================

module "adguard" {
  source = "./modules/vm-bpg"

  vm_id          = var.adguard_vm_id
  vm_name        = "adguard"
  vm_description = "Phase 0 - AdGuard Home DNS Server (Bootstrap Priority 1)"
  tags           = ["infrastructure", "dns", "adguard", "phase0", "bootstrap-first"]
  node_name      = var.proxmox_node
  cpu_cores      = var.adguard_cores
  memory_mb      = var.adguard_memory
  disk_size_gb   = var.adguard_disk_size
  ip_address     = var.adguard_ip
  gateway        = var.gateway
  nameserver     = "1.1.1.1" # Uses external DNS during bootstrap (it IS the DNS server)
  vlan_id        = 20        # Infrastructure VLAN

  ssh_keys = var.ssh_public_key
}

# =============================================================================
# Harbor Container Registry
# =============================================================================

module "harbor" {
  source = "./modules/vm-bpg"

  vm_id          = var.harbor_vm_id
  vm_name        = "harbor"
  vm_description = "Phase 0 - Harbor Container Registry with Trivy scanning"
  tags           = ["infrastructure", "registry", "harbor", "phase0"]
  node_name      = var.proxmox_node
  cpu_cores      = var.harbor_cores
  memory_mb      = var.harbor_memory
  disk_size_gb   = var.harbor_disk_size
  ip_address     = var.harbor_ip
  gateway        = var.gateway
  nameserver     = var.adguard_ip # Uses AdGuard for DNS after bootstrap
  vlan_id        = 20             # Infrastructure VLAN

  ssh_keys = var.ssh_public_key

  depends_on = [module.adguard]
}

# =============================================================================
# GitLab CE - Git Server + CI/CD
# =============================================================================

module "gitlab" {
  source = "./modules/vm-bpg"

  vm_id          = var.gitlab_vm_id
  vm_name        = "gitlab"
  vm_description = "Phase 0 - GitLab CE with CI/CD Runners"
  tags           = ["infrastructure", "git", "gitlab", "cicd", "phase0"]
  node_name      = var.proxmox_node
  cpu_cores      = var.gitlab_cores
  memory_mb      = var.gitlab_memory
  disk_size_gb   = var.gitlab_disk_size
  ip_address     = var.gitlab_ip
  gateway        = var.gateway
  nameserver     = var.adguard_ip # Uses AdGuard for DNS
  vlan_id        = 20             # Infrastructure VLAN

  ssh_keys = var.ssh_public_key

  depends_on = [module.adguard]
}

# =============================================================================
# NetBox - DCIM/IPAM Source of Truth
# =============================================================================

module "netbox" {
  source = "./modules/vm-bpg"

  vm_id          = var.netbox_vm_id
  vm_name        = "netbox"
  vm_description = "Phase 0 - NetBox DCIM/IPAM Infrastructure Source of Truth"
  tags           = ["infrastructure", "dcim", "ipam", "netbox", "phase0", "source-of-truth"]
  node_name      = var.proxmox_node
  cpu_cores      = var.netbox_cores
  memory_mb      = var.netbox_memory
  disk_size_gb   = var.netbox_disk_size
  ip_address     = var.netbox_ip
  gateway        = var.gateway
  nameserver     = var.adguard_ip # Uses AdGuard for DNS
  vlan_id        = 20             # Infrastructure VLAN

  ssh_keys = var.ssh_public_key

  depends_on = [module.adguard]
}

# =============================================================================
# HAProxy Load Balancers
# =============================================================================

module "haproxy_1" {
  source = "./modules/vm-bpg"

  vm_id          = 196
  vm_name        = "haproxy-1"
  vm_description = "Phase 0 - HA Load Balancer + Keepalived (Master)"
  tags           = ["infrastructure", "haproxy", "loadbalancer", "phase0", "ha", "master"]
  node_name      = var.proxmox_node
  cpu_cores      = 2
  memory_mb      = 2048 # Actual: 2GB
  disk_size_gb   = 32
  ip_address     = var.haproxy_1_ip
  gateway        = var.gateway
  nameserver     = var.adguard_ip # Uses AdGuard for DNS
  vlan_id        = 20             # Infrastructure VLAN

  ssh_keys = var.ssh_public_key

  depends_on = [module.adguard]
}

module "haproxy_2" {
  source = "./modules/vm-bpg"

  vm_id          = 197
  vm_name        = "haproxy-2"
  vm_description = "Phase 0 - HA Load Balancer + Keepalived (Backup)"
  tags           = ["infrastructure", "haproxy", "loadbalancer", "phase0", "ha", "backup"]
  node_name      = var.proxmox_node
  cpu_cores      = 2
  memory_mb      = 2048 # Actual: 2GB
  disk_size_gb   = 32
  ip_address     = var.haproxy_2_ip
  gateway        = var.gateway
  nameserver     = var.adguard_ip # Uses AdGuard for DNS
  vlan_id        = 20             # Infrastructure VLAN

  ssh_keys = var.ssh_public_key

  depends_on = [module.haproxy_1]
}

# =============================================================================
# Kubernetes Master Nodes
# =============================================================================

module "k8s_master_1" {
  source = "./modules/vm-bpg"

  vm_id          = 201
  vm_name        = "k8s-master-1"
  vm_description = "Phase 1 - RKE2 Control Plane Node 1"
  tags           = ["kubernetes", "controlplane", "rke2", "phase1", "master"]
  node_name      = var.proxmox_node
  cpu_cores      = var.k8s_master_cores
  memory_mb      = var.k8s_master_memory
  disk_size_gb   = 100
  ip_address     = var.k8s_master_1_ip
  gateway        = var.k8s_gateway
  nameserver     = var.adguard_ip # Uses AdGuard for DNS
  vlan_id        = 30             # Kubernetes VLAN

  ssh_keys = var.ssh_public_key

  depends_on = [module.adguard]
}

module "k8s_master_2" {
  source = "./modules/vm-bpg"

  vm_id          = 202
  vm_name        = "k8s-master-2"
  vm_description = "Phase 1 - RKE2 Control Plane Node 2"
  tags           = ["kubernetes", "controlplane", "rke2", "phase1", "master"]
  node_name      = var.proxmox_node
  cpu_cores      = var.k8s_master_cores
  memory_mb      = var.k8s_master_memory
  disk_size_gb   = 100
  ip_address     = var.k8s_master_2_ip
  gateway        = var.k8s_gateway
  nameserver     = var.adguard_ip # Uses AdGuard for DNS
  vlan_id        = 30             # Kubernetes VLAN

  ssh_keys = var.ssh_public_key

  depends_on = [module.k8s_master_1]
}

module "k8s_master_3" {
  source = "./modules/vm-bpg"

  vm_id          = 203
  vm_name        = "k8s-master-3"
  vm_description = "Phase 1 - RKE2 Control Plane Node 3"
  tags           = ["kubernetes", "controlplane", "rke2", "phase1", "master"]
  node_name      = var.proxmox_node
  cpu_cores      = var.k8s_master_cores
  memory_mb      = var.k8s_master_memory
  disk_size_gb   = 100
  ip_address     = var.k8s_master_3_ip
  gateway        = var.k8s_gateway
  nameserver     = var.adguard_ip # Uses AdGuard for DNS
  vlan_id        = 30             # Kubernetes VLAN

  ssh_keys = var.ssh_public_key

  depends_on = [module.k8s_master_2]
}

# =============================================================================
# Kubernetes Worker Nodes
# =============================================================================

# Worker 1 - WITH GPU passthrough (NVIDIA RTX A2000)
module "k8s_worker_1_gpu" {
  source = "./modules/vm-gpu-bpg"

  vm_id          = 211
  vm_name        = "k8s-worker-1"
  vm_description = "Phase 1 - RKE2 Worker with NVIDIA RTX A2000 GPU"
  tags           = ["kubernetes", "worker", "rke2", "phase1", "gpu", "nvidia"]
  node_name      = var.proxmox_node
  cpu_cores      = var.k8s_worker_1_cores
  memory_mb      = var.k8s_worker_1_memory
  disk_size_gb   = 150
  ip_address     = var.k8s_worker_1_ip
  gateway        = var.k8s_gateway
  nameserver     = var.adguard_ip # Uses AdGuard for DNS
  vlan_id        = 30             # Kubernetes VLAN

  ssh_keys         = var.ssh_public_key
  gpu_mapping_name = "nvidia-rtx-a2000"

  depends_on = [module.k8s_master_3]
}

module "k8s_worker_2" {
  source = "./modules/vm-bpg"

  vm_id          = 212
  vm_name        = "k8s-worker-2"
  vm_description = "Phase 1 - RKE2 Worker Node 2"
  tags           = ["kubernetes", "worker", "rke2", "phase1"]
  node_name      = var.proxmox_node
  cpu_cores      = 4     # Actual: 4 cores
  memory_mb      = 16384 # Actual: 16GB
  disk_size_gb   = 150
  ip_address     = var.k8s_worker_2_ip
  gateway        = var.k8s_gateway
  nameserver     = var.adguard_ip # Uses AdGuard for DNS
  vlan_id        = 30             # Kubernetes VLAN

  ssh_keys = var.ssh_public_key

  depends_on = [module.k8s_worker_1_gpu]
}

module "k8s_worker_3" {
  source = "./modules/vm-bpg"

  vm_id          = 213
  vm_name        = "k8s-worker-3"
  vm_description = "Phase 1 - RKE2 Worker Node 3"
  tags           = ["kubernetes", "worker", "rke2", "phase1"]
  node_name      = var.proxmox_node
  cpu_cores      = 4
  memory_mb      = 16384
  disk_size_gb   = 200
  ip_address     = var.k8s_worker_3_ip
  gateway        = var.k8s_gateway
  nameserver     = var.adguard_ip # Uses AdGuard for DNS
  vlan_id        = 30             # Kubernetes VLAN

  ssh_keys = var.ssh_public_key

  depends_on = [module.k8s_worker_2]
}

# =============================================================================
# CI Runner - Dedicated GitLab Runner for deploy jobs
# Docker executor with host networking for reliable cross-VLAN SSH
# =============================================================================

module "ci_runner" {
  source = "./modules/vm-bpg"

  vm_id          = 105
  vm_name        = "ci-runner"
  vm_description = "Phase 0 - Dedicated GitLab Runner for Ansible/Terraform deploy jobs"
  tags           = ["infrastructure", "ci", "runner", "gitlab-runner", "phase0"]
  node_name      = var.proxmox_node
  cpu_cores      = 4
  memory_mb      = 8192
  disk_size_gb   = 50
  ip_address     = var.ci_runner_ip
  gateway        = var.gateway
  nameserver     = var.adguard_ip
  vlan_id        = 20 # Infrastructure VLAN

  ssh_keys = var.ssh_public_key

  depends_on = [module.adguard]
}

# =============================================================================
# AMP - CubeCoders Game Server Control Panel
# =============================================================================

module "amp" {
  source = "./modules/vm-bpg"

  vm_id          = 117
  vm_name        = "amp"
  vm_description = "Phase 0 - CubeCoders AMP Game Server Control Panel"
  tags           = ["infrastructure", "gameserver", "amp", "phase0"]
  node_name      = var.proxmox_node
  cpu_cores      = 4
  memory_mb      = 16384 # Actual: 16GB
  disk_size_gb   = 400   # Expanded 2026-04-18: 194G/197G used — CS2/Prominence2/Factorio instances. Game data to move to TrueNAS iSCSI in follow-up.
  ip_address     = var.amp_ip
  gateway        = var.gateway
  nameserver     = var.adguard_ip
  vlan_id        = 20 # Infrastructure VLAN

  ssh_keys = var.ssh_public_key

  depends_on = [module.adguard]
}

# =============================================================================
# =============================================================================


# =============================================================================
# VPN - WireGuard (wg-easy) for Remote Access
# =============================================================================

module "vpn" {
  source = "./modules/vm-bpg"

  vm_id          = 110
  vm_name        = "vpn"
  vm_description = "Phase 0 - WireGuard VPN (wg-easy) - DMZ VLAN 60 isolated"
  tags           = ["infrastructure", "vpn", "wireguard", "wg-easy", "dmz", "phase0"]
  node_name      = var.proxmox_node
  cpu_cores      = 8 # Actual: 8 cores
  memory_mb      = 2048
  disk_size_gb   = 32
  ip_address     = var.vpn_ip
  gateway        = var.vpn_gateway
  nameserver     = var.adguard_ip # Uses AdGuard for DNS
  vlan_id        = 60             # DMZ VLAN - isolated from management

  ssh_keys = var.ssh_public_key

  depends_on = [module.adguard]
}
# Pipeline trigger: 2025-12-15 - Fix age key mixed case with uppercase normalization
