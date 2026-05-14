# =============================================================================
# Terraform Variables
# =============================================================================

variable "proxmox_host" {
  description = "Proxmox host IP or hostname"
  type        = string
  validation {
    condition     = can(regex("^[a-zA-Z0-9][a-zA-Z0-9.-]*$", var.proxmox_host))
    error_message = "Proxmox host must be a valid hostname or IP address."
  }
}

variable "proxmox_node" {
  description = "Proxmox node name"
  type        = string
  validation {
    condition     = can(regex("^[a-zA-Z][a-zA-Z0-9-]*$", var.proxmox_node))
    error_message = "Proxmox node must be a valid node name (alphanumeric, starting with letter)."
  }
}

variable "proxmox_user" {
  description = "Proxmox API user or API token ID"
  type        = string
  validation {
    condition     = can(regex("^[a-zA-Z0-9_-]+@(pam|pve)(![a-zA-Z0-9_-]+)?$", var.proxmox_user))
    error_message = "Proxmox user must be in format 'user@pam', 'user@pve', or 'user@pam!tokenid'."
  }
}

variable "proxmox_password" {
  description = "Proxmox API password"
  type        = string
  sensitive   = true
  validation {
    condition     = length(var.proxmox_password) > 0
    error_message = "Proxmox API password must not be empty."
  }
}

variable "proxmox_tls_insecure" {
  description = "Skip TLS verification for Proxmox API"
  type        = bool
  default     = false
}

variable "template_vm_id" {
  description = "Template VM ID to clone from"
  type        = string
  default     = "9100"
  validation {
    condition     = can(regex("^[0-9]+$", var.template_vm_id)) && tonumber(var.template_vm_id) >= 100 && tonumber(var.template_vm_id) <= 999999
    error_message = "Template VM ID must be a number between 100 and 999999."
  }
}

variable "ssh_public_key" {
  description = "SSH public key for VM access"
  type        = string
  validation {
    condition     = can(regex("^(ssh-rsa|ssh-ed25519|ecdsa-sha2-nistp[0-9]+) ", var.ssh_public_key))
    error_message = "SSH public key must start with ssh-rsa, ssh-ed25519, or ecdsa-sha2-nistp*."
  }
}

# Network Configuration
variable "gateway" {
  description = "Network gateway for infrastructure VLAN 10"
  type        = string
  validation {
    condition     = can(regex("^((25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\\.){3}(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$", var.gateway))
    error_message = "Gateway must be a valid IPv4 address."
  }
}

variable "k8s_gateway" {
  description = "Network gateway for Kubernetes VLAN 20"
  type        = string
  default     = "<internal-ip>"
  validation {
    condition     = can(regex("^((25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\\.){3}(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$", var.k8s_gateway))
    error_message = "Kubernetes gateway must be a valid IPv4 address."
  }
}

variable "dns_primary" {
  description = "Primary DNS server"
  type        = string
  validation {
    condition     = can(regex("^((25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\\.){3}(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$", var.dns_primary))
    error_message = "DNS server must be a valid IPv4 address."
  }
}

# =============================================================================
# AdGuard DNS VM - FIRST in bootstrap order
# =============================================================================
variable "adguard_vm_id" {
  description = "Proxmox VM ID for AdGuard DNS server"
  type        = number
  default     = 104
  validation {
    condition     = var.adguard_vm_id >= 100 && var.adguard_vm_id <= 999999
    error_message = "VM ID must be between 100 and 999999."
  }
}

variable "adguard_ip" {
  description = "AdGuard Home DNS server IP"
  type        = string
  validation {
    condition     = can(regex("^((25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\\.){3}(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$", var.adguard_ip))
    error_message = "AdGuard IP must be a valid IPv4 address."
  }
}

variable "adguard_cores" {
  description = "Number of CPU cores for AdGuard VM"
  type        = number
  default     = 2
  validation {
    condition     = var.adguard_cores >= 1 && var.adguard_cores <= 64
    error_message = "CPU cores must be between 1 and 64."
  }
}

variable "adguard_memory" {
  description = "Memory allocation in MB for AdGuard VM"
  type        = number
  default     = 2048
  validation {
    condition     = var.adguard_memory >= 512 && var.adguard_memory <= 131072
    error_message = "Memory must be between 512 MB and 128 GB (131072 MB)."
  }
}

variable "adguard_disk_size" {
  description = "Root disk size in GB for AdGuard VM"
  type        = number
  default     = 32
  validation {
    condition     = var.adguard_disk_size >= 10 && var.adguard_disk_size <= 2048
    error_message = "Disk size must be between 10 GB and 2048 GB."
  }
}

# =============================================================================
# Harbor VM
# =============================================================================
variable "harbor_vm_id" {
  description = "Proxmox VM ID for Harbor container registry"
  type        = number
  default     = 101
  validation {
    condition     = var.harbor_vm_id >= 100 && var.harbor_vm_id <= 999999
    error_message = "VM ID must be between 100 and 999999."
  }
}

variable "harbor_ip" {
  description = "Harbor container registry IP address"
  type        = string
  validation {
    condition     = can(regex("^((25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\\.){3}(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$", var.harbor_ip))
    error_message = "Harbor IP must be a valid IPv4 address."
  }
}

variable "harbor_cores" {
  description = "Number of CPU cores for Harbor VM"
  type        = number
  default     = 4
  validation {
    condition     = var.harbor_cores >= 1 && var.harbor_cores <= 64
    error_message = "CPU cores must be between 1 and 64."
  }
}

variable "harbor_memory" {
  description = "Memory allocation in MB for Harbor VM"
  type        = number
  default     = 8192
  validation {
    condition     = var.harbor_memory >= 512 && var.harbor_memory <= 131072
    error_message = "Memory must be between 512 MB and 128 GB (131072 MB)."
  }
}

variable "harbor_disk_size" {
  description = "Root disk size in GB for Harbor VM"
  type        = number
  default     = 100
  validation {
    condition     = var.harbor_disk_size >= 10 && var.harbor_disk_size <= 2048
    error_message = "Disk size must be between 10 GB and 2048 GB."
  }
}

# =============================================================================
# GitLab VM
# =============================================================================
variable "gitlab_vm_id" {
  description = "Proxmox VM ID for GitLab CE server"
  type        = number
  default     = 102
  validation {
    condition     = var.gitlab_vm_id >= 100 && var.gitlab_vm_id <= 999999
    error_message = "VM ID must be between 100 and 999999."
  }
}

variable "gitlab_ip" {
  description = "GitLab CE server IP address"
  type        = string
  validation {
    condition     = can(regex("^((25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\\.){3}(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$", var.gitlab_ip))
    error_message = "GitLab IP must be a valid IPv4 address."
  }
}

variable "gitlab_cores" {
  description = "Number of CPU cores for GitLab VM"
  type        = number
  default     = 6
  validation {
    condition     = var.gitlab_cores >= 1 && var.gitlab_cores <= 64
    error_message = "CPU cores must be between 1 and 64."
  }
}

variable "gitlab_memory" {
  description = "Memory allocation in MB for GitLab VM"
  type        = number
  default     = 12288
  validation {
    condition     = var.gitlab_memory >= 512 && var.gitlab_memory <= 131072
    error_message = "Memory must be between 512 MB and 128 GB (131072 MB)."
  }
}

variable "gitlab_disk_size" {
  description = "Root disk size in GB for GitLab VM"
  type        = number
  default     = 100
  validation {
    condition     = var.gitlab_disk_size >= 10 && var.gitlab_disk_size <= 2048
    error_message = "Disk size must be between 10 GB and 2048 GB."
  }
}

# =============================================================================
# NetBox VM
# =============================================================================
variable "netbox_vm_id" {
  description = "Proxmox VM ID for NetBox DCIM/IPAM server"
  type        = number
  default     = 103
  validation {
    condition     = var.netbox_vm_id >= 100 && var.netbox_vm_id <= 999999
    error_message = "VM ID must be between 100 and 999999."
  }
}

variable "netbox_ip" {
  description = "NetBox DCIM/IPAM server IP"
  type        = string
  validation {
    condition     = can(regex("^((25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\\.){3}(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$", var.netbox_ip))
    error_message = "NetBox IP must be a valid IPv4 address."
  }
}

variable "netbox_cores" {
  description = "Number of CPU cores for NetBox VM"
  type        = number
  default     = 2
  validation {
    condition     = var.netbox_cores >= 1 && var.netbox_cores <= 64
    error_message = "CPU cores must be between 1 and 64."
  }
}

variable "netbox_memory" {
  description = "Memory allocation in MB for NetBox VM"
  type        = number
  default     = 4096
  validation {
    condition     = var.netbox_memory >= 512 && var.netbox_memory <= 131072
    error_message = "Memory must be between 512 MB and 128 GB (131072 MB)."
  }
}

variable "netbox_disk_size" {
  description = "Root disk size in GB for NetBox VM"
  type        = number
  default     = 50
  validation {
    condition     = var.netbox_disk_size >= 10 && var.netbox_disk_size <= 2048
    error_message = "Disk size must be between 10 GB and 2048 GB."
  }
}

# CI Runner - Dedicated GitLab Runner VM for deploy jobs
variable "ci_runner_ip" {
  description = "CI Runner IP address (Infrastructure VLAN 20)"
  type        = string
  validation {
    condition     = can(regex("^((25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\\.){3}(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$", var.ci_runner_ip))
    error_message = "CI Runner IP must be a valid IPv4 address."
  }
}

# AMP Game Server Control Panel
variable "amp_ip" {
  description = "AMP game server control panel IP (Infrastructure VLAN 20 - per config/network.yaml)"
  type        = string
  # Value defined in terraform.tfvars, sourced from config/network.yaml:
  # vlans.infrastructure.static_allocations.amp
  validation {
    condition     = can(regex("^((25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\\.){3}(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$", var.amp_ip))
    error_message = "AMP IP must be a valid IPv4 address."
  }
}

# Kubernetes Masters
variable "k8s_master_cores" {
  description = "Number of CPU cores for each Kubernetes master node"
  type        = number
  default     = 4
  validation {
    condition     = var.k8s_master_cores >= 2 && var.k8s_master_cores <= 64
    error_message = "Kubernetes master cores must be between 2 and 64 (minimum 2 for control plane)."
  }
}

variable "k8s_master_memory" {
  description = "Memory allocation in MB for each Kubernetes master node"
  type        = number
  default     = 10240
  validation {
    condition     = var.k8s_master_memory >= 2048 && var.k8s_master_memory <= 131072
    error_message = "Kubernetes master memory must be between 2 GB (2048 MB) and 128 GB (minimum 2 GB for etcd)."
  }
}

variable "k8s_master_disk_size" {
  description = "Root disk size for Kubernetes master nodes (e.g., '100G')"
  type        = string
  default     = "100G"
  validation {
    condition     = can(regex("^[0-9]+G$", var.k8s_master_disk_size))
    error_message = "Disk size must be in format 'NUMBERg' (e.g., '100G')."
  }
}

variable "k8s_master_1_ip" {
  description = "IP address for Kubernetes master node 1"
  type        = string
  validation {
    condition     = can(regex("^((25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\\.){3}(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$", var.k8s_master_1_ip))
    error_message = "Must be a valid IPv4 address."
  }
}

variable "k8s_master_2_ip" {
  description = "IP address for Kubernetes master node 2"
  type        = string
  validation {
    condition     = can(regex("^((25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\\.){3}(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$", var.k8s_master_2_ip))
    error_message = "Must be a valid IPv4 address."
  }
}

variable "k8s_master_3_ip" {
  description = "IP address for Kubernetes master node 3"
  type        = string
  validation {
    condition     = can(regex("^((25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\\.){3}(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$", var.k8s_master_3_ip))
    error_message = "Must be a valid IPv4 address."
  }
}

# Kubernetes Workers
variable "k8s_worker_1_cores" {
  description = "Number of CPU cores for Kubernetes worker node 1"
  type        = number
  default     = 8
  validation {
    condition     = var.k8s_worker_1_cores >= 2 && var.k8s_worker_1_cores <= 64
    error_message = "Worker cores must be between 2 and 64."
  }
}

variable "k8s_worker_1_memory" {
  description = "Memory allocation in MB for Kubernetes worker node 1"
  type        = number
  default     = 16384
  validation {
    condition     = var.k8s_worker_1_memory >= 2048 && var.k8s_worker_1_memory <= 131072
    error_message = "Worker memory must be between 2 GB (2048 MB) and 128 GB."
  }
}

variable "k8s_worker_1_disk_size" {
  description = "Root disk size for Kubernetes worker node 1 (e.g., '150G')"
  type        = string
  default     = "150G"
  validation {
    condition     = can(regex("^[0-9]+G$", var.k8s_worker_1_disk_size))
    error_message = "Disk size must be in format 'NUMBERG' (e.g., '150G')."
  }
}

variable "k8s_worker_1_ip" {
  description = "IP address for Kubernetes worker node 1"
  type        = string
  validation {
    condition     = can(regex("^((25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\\.){3}(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$", var.k8s_worker_1_ip))
    error_message = "Must be a valid IPv4 address."
  }
}

variable "k8s_worker_2_cores" {
  description = "Number of CPU cores for Kubernetes worker node 2"
  type        = number
  default     = 8
  validation {
    condition     = var.k8s_worker_2_cores >= 2 && var.k8s_worker_2_cores <= 64
    error_message = "Worker cores must be between 2 and 64."
  }
}

variable "k8s_worker_2_memory" {
  description = "Memory allocation in MB for Kubernetes worker node 2"
  type        = number
  default     = 16384
  validation {
    condition     = var.k8s_worker_2_memory >= 2048 && var.k8s_worker_2_memory <= 131072
    error_message = "Worker memory must be between 2 GB (2048 MB) and 128 GB."
  }
}

variable "k8s_worker_2_disk_size" {
  description = "Root disk size for Kubernetes worker node 2 (e.g., '150G')"
  type        = string
  default     = "150G"
  validation {
    condition     = can(regex("^[0-9]+G$", var.k8s_worker_2_disk_size))
    error_message = "Disk size must be in format 'NUMBERG' (e.g., '150G')."
  }
}

variable "k8s_worker_2_ip" {
  description = "IP address for Kubernetes worker node 2"
  type        = string
  validation {
    condition     = can(regex("^((25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\\.){3}(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$", var.k8s_worker_2_ip))
    error_message = "Must be a valid IPv4 address."
  }
}

variable "k8s_worker_3_cores" {
  description = "Number of CPU cores for Kubernetes worker node 3 (GPU node)"
  type        = number
  default     = 8
  validation {
    condition     = var.k8s_worker_3_cores >= 2 && var.k8s_worker_3_cores <= 64
    error_message = "Worker cores must be between 2 and 64."
  }
}

variable "k8s_worker_3_memory" {
  description = "Memory allocation in MB for Kubernetes worker node 3 (GPU node, higher default)"
  type        = number
  default     = 20480
  validation {
    condition     = var.k8s_worker_3_memory >= 2048 && var.k8s_worker_3_memory <= 131072
    error_message = "Worker memory must be between 2 GB (2048 MB) and 128 GB."
  }
}

variable "k8s_worker_3_disk_size" {
  description = "Root disk size for Kubernetes worker node 3 (GPU node, larger default)"
  type        = string
  default     = "200G"
  validation {
    condition     = can(regex("^[0-9]+G$", var.k8s_worker_3_disk_size))
    error_message = "Disk size must be in format 'NUMBERG' (e.g., '200G')."
  }
}

variable "k8s_worker_3_ip" {
  description = "IP address for Kubernetes worker node 3 (GPU node)"
  type        = string
  validation {
    condition     = can(regex("^((25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\\.){3}(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$", var.k8s_worker_3_ip))
    error_message = "Must be a valid IPv4 address."
  }
}

# GPU Configuration
variable "gpu_device_id" {
  description = "GPU PCI device ID (e.g., '0000:00:02.0' for Intel iGPU)"
  type        = string
  default     = "0000:00:02.0"
  validation {
    condition     = can(regex("^[0-9a-fA-F]{4}:[0-9a-fA-F]{2}:[0-9a-fA-F]{2}\\.[0-9a-fA-F]$", var.gpu_device_id))
    error_message = "GPU device ID must be in PCI format (e.g., '0000:00:02.0')."
  }
}

# HAProxy
variable "haproxy_1_ip" {
  description = "HAProxy 1 IP address"
  type        = string
  validation {
    condition     = can(regex("^((25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\\.){3}(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$", var.haproxy_1_ip))
    error_message = "HAProxy 1 IP must be a valid IPv4 address."
  }
}

variable "haproxy_2_ip" {
  description = "HAProxy 2 IP address"
  type        = string
  validation {
    condition     = can(regex("^((25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\\.){3}(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$", var.haproxy_2_ip))
    error_message = "HAProxy 2 IP must be a valid IPv4 address."
  }
}

# TrueNAS
variable "truenas_ip" {
  description = "TrueNAS IP address"
  type        = string
  validation {
    condition     = can(regex("^((25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\\.){3}(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$", var.truenas_ip))
    error_message = "TrueNAS IP must be a valid IPv4 address."
  }
}

variable "seedbox_ip" {
  type        = string
  validation {
    condition     = can(regex("^((25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\\.){3}(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$", var.seedbox_ip))
  }
}

# VPN (WireGuard wg-easy)
variable "vpn_ip" {
  description = "VPN (wg-easy) IP address on DMZ VLAN 60"
  type        = string
  validation {
    condition     = can(regex("^((25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\\.){3}(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$", var.vpn_ip))
    error_message = "VPN IP must be a valid IPv4 address."
  }
}

variable "vpn_gateway" {
  description = "DMZ VLAN 60 gateway"
  type        = string
  default     = "<internal-ip>"
  validation {
    condition     = can(regex("^((25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\\.){3}(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$", var.vpn_gateway))
    error_message = "VPN gateway must be a valid IPv4 address."
  }
}

variable "truenas_data_disks" {
  description = "List of WWN disk paths for TrueNAS data pool (auto-discovered)"
  type        = list(string)
  default     = []
  # Populated by scripts/discover-truenas-disks.sh  truenas_disks.auto.tfvars
  # Each disk is a /dev/disk/by-id/wwn-* path for stable identification
  validation {
    condition     = alltrue([for d in var.truenas_data_disks : can(regex("^/dev/disk/by-id/", d))])
    error_message = "Each TrueNAS data disk must be a /dev/disk/by-id/ path for stable identification."
  }
}

variable "template_name" {
  description = "Template name for VM cloning"
  type        = string
  default     = "rocky-linux-9.5-template"
  validation {
    condition     = can(regex("^[a-zA-Z0-9][a-zA-Z0-9._-]*$", var.template_name))
    error_message = "Template name must be alphanumeric with dots, underscores, and hyphens allowed."
  }
}

