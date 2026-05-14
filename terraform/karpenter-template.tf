# =============================================================================
# Karpenter VM Template — Debian 13 with VLAN 30 (K8s network)
# =============================================================================
# Cloned from the base debian-13-cloud-template (ID 9000).
# Used by karpenter-provider-proxmox to provision worker nodes.
#
# Base template (9000) is on untagged VLAN (management) and shared by other VMs.
# This template is identical but on VLAN 30 for K8s worker placement.
#
# To rebuild: terraform apply -target=proxmox_virtual_environment_vm.karpenter_template

resource "proxmox_virtual_environment_vm" "karpenter_template" {
  name      = "karpenter-k8s-worker-template"
  node_name = "salty"
  vm_id     = 9001
  template  = true
  tags      = ["kubernetes", "karpenter", "template", "phase1"]

  description = <<-EOT
    Karpenter auto-provisioning template.
    VLAN 30 (K8s network), cloud-init enabled, QEMU guest agent.
    Managed by Terraform — do not modify manually.
  EOT

  clone {
    vm_id = 9000 # debian-13-cloud-template (base)
    full  = true
  }

  cpu {
    cores   = 2
    sockets = 1
    type    = "host"
  }

  memory {
    dedicated = 2048
  }

  # VLAN 30 — K8s network (10.x0.0/24)
  network_device {
    bridge  = "vmbr1"
    vlan_id = 30
    model   = "virtio"
  }

  disk {
    datastore_id = "local-zfs"
    interface    = "scsi0"
    size         = 32
  }

  operating_system {
    type = "l26"
  }

  initialization {
    ip_config {
      ipv4 {
        address = "dhcp"
      }
    }
    datastore_id = "local-zfs"
  }

  agent {
    enabled = true
  }

  lifecycle {
    ignore_changes = [
      disk,
    ]
  }
}

# =============================================================================
# Output for reference by Karpenter NodeClass
# =============================================================================
output "karpenter_template_name" {
  value       = proxmox_virtual_environment_vm.karpenter_template.name
  description = "Template name referenced in ProxmoxUnmanagedTemplate"
}

output "karpenter_template_id" {
  value       = proxmox_virtual_environment_vm.karpenter_template.vm_id
  description = "Proxmox VM ID of the Karpenter template"
}
