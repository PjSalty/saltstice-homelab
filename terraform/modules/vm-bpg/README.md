# VM Module (BPG Provider)

Standard Proxmox VM module using the BPG provider. Creates Debian 13 VMs from cloud-init template.

## Features

- Full clone from VM template (ID 9000)
- Cloud-init configuration
- VLAN support
- VirtIO networking
- SCSI disk with io threading

## Requirements

| Name | Version |
|------|---------|
| Terraform | >= 1.5.0 |
| Proxmox (bpg) | ~> 0.88.0 |

## Prerequisites

1. **VM Template**: Debian 13 cloud template must exist as VM ID 9000
2. **Storage**: `local-zfs` datastore must be available
3. **Network**: `vmbr0` bridge must exist

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| vm_id | VM ID in Proxmox (100-999999) | `number` | n/a | yes |
| vm_name | VM name | `string` | n/a | yes |
| node_name | Proxmox node name | `string` | n/a | yes |
| cpu_cores | Number of CPU cores (1-64) | `number` | n/a | yes |
| memory_mb | Memory in MB (512-131072) | `number` | n/a | yes |
| disk_size_gb | Disk size in GB | `number` | n/a | yes |
| ip_address | IP address without CIDR notation | `string` | n/a | yes |
| gateway | Gateway IP address | `string` | n/a | yes |
| nameserver | DNS nameserver IP | `string` | n/a | yes |
| ssh_keys | SSH public key for cloud-init | `string` | n/a | yes |
| vlan_id | VLAN tag (0 = no VLAN) | `number` | `0` | no |
| vm_description | Description shown in Proxmox | `string` | `""` | no |
| tags | List of tags for the VM | `list(string)` | `[]` | no |

## Outputs

| Name | Description |
|------|-------------|
| ip_address | VM IP address |
| vm_name | VM name |
| vm_id | VM ID |

## Usage

```hcl
module "k8s_worker" {
  source = "./modules/vm-bpg"

  vm_id       = 201
  vm_name     = "k8s-worker-01"
  node_name   = "proxmox"
  cpu_cores   = 4
  memory_mb   = 8192
  disk_size_gb = 50
  ip_address  = "10.x0.21"
  gateway     = "10.x0.1"
  nameserver  = "<internal-ip>"
  ssh_keys    = var.ssh_public_key
  vlan_id     = 30
  tags        = ["kubernetes", "worker"]
}
```

## Notes

- QEMU Guest Agent is disabled to prevent Terraform hangs
- Uses `host` CPU type for best performance
- Disk uses io threading for improved i/O

## Related

- [vm-GPU-bpg](../vm-gpu-bpg) - GPU passthrough variant
