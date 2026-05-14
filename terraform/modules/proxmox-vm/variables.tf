variable "vm_id" {
  description = "Proxmox VM ID"
  type        = number
}

variable "vm_name" {
  description = "Proxmox VM name"
  type        = string
}

variable "node_name" {
  description = "Proxmox node name"
  type        = string
}

variable "cpu_cores" {
  description = "Number of vCPU cores"
  type        = number
}

variable "memory_mb" {
  description = "Memory in MB"
  type        = number
}

variable "disk_size_gb" {
  description = "Boot disk size in GB"
  type        = number
}

variable "ip_address" {
  description = "Static IPv4 address (no CIDR)"
  type        = string
}

variable "gateway" {
  description = "Default gateway IPv4"
  type        = string
}

variable "nameserver" {
  description = "DNS resolver IPv4"
  type        = string
}

variable "ssh_keys" {
  description = "SSH public key for the cloud-init debian user"
  type        = string
}

variable "vlan_id" {
  description = "VLAN tag (0 = untagged)"
  type        = number
  default     = 0
}

variable "vm_description" {
  description = "Description shown in Proxmox UI"
  type        = string
  default     = ""
}

variable "tags" {
  description = "Tags shown in Proxmox UI"
  type        = list(string)
  default     = []
}

variable "template_vm_id" {
  description = "Source template VM ID (Debian 13 cloud-init)"
  type        = number
  default     = 9000
}
