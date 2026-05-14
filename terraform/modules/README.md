# Terraform Modules

Reusable Terraform modules for provisioning Proxmox VMs. All modules use the BPG Proxmox provider (`bpg/proxmox`).

## Modules

### vm-bpg

Standard VM module for creating Proxmox VMs with cloud-init.

| Variable | Type | Description |
|----------|------|-------------|
| `vm_name` | string | VM hostname |
| `vm_id` | number | Proxmox VM ID |
| `target_node` | string | Proxmox node to deploy on |
| `template_vm_id` | number | Template VM to clone from (default: 9000) |
| `cores` | number | CPU cores |
| `memory` | number | RAM in MB |
| `disk_size` | number | Boot disk size in GB |
| `ip_address` | string | Static IP (CIDR notation) |
| `gateway` | string | Default gateway |
| `vlan_tag` | number | VLAN tag for the network interface |
| `ssh_keys` | list(string) | SSH public keys for cloud-init |

Features: VirtIO-SCSI-single controller, SSD emulation, discard support, QEMU guest agent, cloud-init user data.

See [vm-bpg/README.md](vm-bpg/README.md) for full documentation.

### vm-GPU-bpg

GPU passthrough variant of the standard VM module. Adds PCI passthrough configuration for the NVIDIA RTX A2000.

| Additional Variable | Type | Description |
|---------------------|------|-------------|
| `pci_device_id` | string | PCI address of the GPU (e.g., `0000:01:00`) |

Uses Q35 machine type and OVMF (UEFI) BIOS required for PCI passthrough. CPU type is set to `host` for IOMMU support.

See [vm-GPU-bpg/README.md](vm-gpu-bpg/README.md) for full documentation.

## Usage

Modules are referenced from `main.tf` in the repository root:

```hcl
module "gitlab" {
  source = "./modules/vm-bpg"

  vm_name       = "gitlab"
  vm_id         = 101
  target_node   = var.proxmox_node
  cores         = 4
  memory        = 8192
  disk_size     = 50
  ip_address    = "<internal-ip>/24"
  gateway       = "<internal-ip>"
  vlan_tag      = 20
  ssh_keys      = [var.ssh_public_key]
}

module "k8s_worker_1_gpu" {
  source = "./modules/vm-gpu-bpg"

  vm_name       = "k8s-worker-1"
  vm_id         = 211
  target_node   = var.proxmox_node
  cores         = 4
  memory        = 16384
  disk_size     = 50
  ip_address    = "10.x0.21/24"
  gateway       = "10.x0.1"
  vlan_tag      = 30
  ssh_keys      = [var.ssh_public_key]
  pci_device_id = "0000:01:00"
}
```

## Outputs

Both modules expose:

| Output | Description |
|--------|-------------|
| `vm_name` | The VM name |
| `ip_address` | The assigned IP address |
