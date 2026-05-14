variable "vm_id" {
  description = "VM ID"
  type        = number
}

variable "vm_name" {
  description = "VM name"
  type        = string
}

variable "node_name" {
  description = "Proxmox node name"
  type        = string
}

variable "cpu_cores" {
  description = "Number of CPU cores"
  type        = number
}

variable "memory_mb" {
  description = "Memory in MB"
  type        = number
}

variable "disk_size_gb" {
  description = "Disk size in GB"
  type        = number
}

variable "ip_address" {
  description = "IP address (without CIDR)"
  type        = string
}

variable "gateway" {
  description = "Gateway IP"
  type        = string
}

variable "nameserver" {
  description = "DNS nameserver"
  type        = string
}

variable "ssh_keys" {
  description = "SSH public key"
  type        = string
}

variable "vlan_id" {
  description = "VLAN tag for network interface (0 = no VLAN)"
  type        = number
  default     = 0
}

variable "vm_description" {
  description = "VM description shown in Proxmox"
  type        = string
  default     = ""
}

variable "tags" {
  description = "List of tags for the VM"
  type        = list(string)
  default     = []
}

variable "template_vm_id" {
  description = "Clone source template VM ID"
  type        = number
  default     = 9000
}
