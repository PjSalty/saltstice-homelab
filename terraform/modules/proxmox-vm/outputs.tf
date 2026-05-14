output "vm_id" {
  description = "Proxmox VM ID"
  value       = proxmox_virtual_environment_vm.vm.vm_id
}

output "vm_name" {
  description = "Proxmox VM name"
  value       = proxmox_virtual_environment_vm.vm.name
}

output "ip_address" {
  description = "Static IPv4 address"
  value       = var.ip_address
}
