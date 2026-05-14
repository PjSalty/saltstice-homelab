# VM GPU Module (BPG Provider)

Proxmox VM module with GPU passthrough using the BPG provider. Creates Debian 13 VMs with PCIe GPU passthrough.

## Features

- Full clone from VM template (ID 9000)
- PCIe GPU passthrough via PCI mapping
- Q35 machine type for PCIe support
- Cloud-init configuration
- VLAN support

## Requirements

| Name | Version |
|------|---------|
| Terraform | >= 1.5.0 |
| Proxmox (bpg) | ~> 0.88.0 |

## Prerequisites

1. **VM Template**: Debian 13 cloud template must exist as VM ID 9000
2. **Storage**: `local-zfs` datastore must be available
3. **Network**: `vmbr0` bridge must exist
4. **GPU Mapping**: PCI mapping must be configured in Proxmox

### GPU Mapping Setup

Create PCI mapping in `/etc/pve/mapping/pci.cfg`:

```
map: nvidia-rtx-a2000
    map proxmox 0000:01:00
```

Or via Proxmox UI: Datacenter → Resource Mappings → PCI Devices

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
| gpu_mapping_name | PCI mapping name from Proxmox | `string` | n/a | yes |
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
module "jellyfin" {
  source = "./modules/vm-gpu-bpg"

  vm_id            = 300
  vm_name          = "jellyfin"
  node_name        = "proxmox"
  cpu_cores        = 4
  memory_mb        = 16384
  disk_size_gb     = 100
  ip_address       = "<internal-ip>"
  gateway          = "<internal-ip>"
  nameserver       = "<internal-ip>"
  ssh_keys         = var.ssh_public_key
  gpu_mapping_name = "nvidia-rtx-a2000"
  vlan_id          = 50
  tags             = ["media", "gpu"]
}
```

## GPU Driver Installation

After VM creation, install NVIDIA drivers:

```bash
# Add NVIDIA repo (Debian 13)
sudo apt install -y nvidia-driver firmware-misc-nonfree

# Verify GPU
nvidia-smi
```

## Notes

- Uses Q35 machine type (required for PCIe passthrough)
- QEMU Guest Agent is disabled to prevent Terraform hangs
- ROM BAR is enabled for GPU VBIOS
- GPU is passed through as PCIe device (not legacy PCI)

## Troubleshooting

### GPU not visible in VM

1. Verify IOMMU is enabled in BIOS
2. Check kernel parameters: `intel_iommu=on` or `amd_iommu=on`
3. Verify PCI mapping exists: `pvesh get /cluster/mapping/pci`

### VM fails to start

1. Check if GPU is in use by host
2. Blacklist host GPU drivers: `vfio-pci.ids=10de:xxxx`
3. Verify mapping name matches exactly

## Related

- [vm-bpg](../vm-bpg) - Standard VM module (no GPU)
