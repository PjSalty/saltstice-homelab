# Proxmox-vm

Reusable Terraform module for provisioning Proxmox VMs from a
cloud-init template. Used to bring up every VM in the homelab.
storage, K8s control plane, K8s workers (static + Karpenter-managed),
ingress, registry, identity.

Provider: `bpg/proxmox` (`~> 0.106.0`).

## Usage

```hcl
module "k8s_master_1" {
  source = "./modules/proxmox-vm"

  vm_id          = 110
  vm_name        = "k8s-master-1"
  node_name      = "proxmox"
  template_vm_id = 9000             # Debian 13 cloud-init template

  cpu_cores    = 4
  memory_mb    = 8192
  disk_size_gb = 50

  ip_address = "<internal-ip>"
  gateway    = "<internal-ip>"
  vlan_id    = 30
  nameserver = "<internal-ip>"
  ssh_keys   = var.ssh_public_key

  tags = ["kubernetes", "control-plane"]
}
```

## What's in the module

- `bpg/proxmox` provider pinned to `~> 0.106.0`
- `proxmox_virtual_environment_vm` resource cloning from a configurable
 Debian 13 template (default `vm_id = 9000`)
- `virtio-scsi-single` controller, `local-zfs` datastore
- Cloud-init initialization with IP/gateway/DNS/SSH key on first boot
- `cpu.type = "host"`, NUMA enabled
- Lifecycle: `prevent_destroy = true` plus an `ignore_changes` list that
 keeps Terraform from fighting Proxmox GUI / Ansible / cosmetic drift
 for things like NIC config, VGA type, tags, descriptions, startup
 ordering, RNG device

## Why `ignore_changes` is so long

Proxmox VMs accumulate state from multiple sources, the GUI, Ansible,
cloud-init re-runs, manual operator changes. Terraform's default
behavior would try to revert every one of those drifts every plan,
which means slow applies and unnecessary VM restarts (VGA changes
alone are 15+ minutes). The ignore list documents which attributes
are intentionally drifted vs. Unmanaged.

## Inputs

| Variable | Type | Default | Notes |
|---|---|---|---|
| `vm_id` | number |, | Required |
| `vm_name` | string |, | Required |
| `node_name` | string |, | Required, Proxmox node |
| `cpu_cores` | number |, | Required |
| `memory_mb` | number |, | Required |
| `disk_size_gb` | number |, | Required |
| `ip_address` | string |, | Required, no CIDR |
| `gateway` | string |, | Required |
| `nameserver` | string |, | Required |
| `ssh_keys` | string |, | Public key |
| `vlan_id` | number | `0` | `0` = untagged |
| `vm_description` | string | `""` | Cosmetic |
| `tags` | list(string) | `[]` | Cosmetic |
| `template_vm_id` | number | `9000` | Source template |

## Sister module

`proxmox-vm-gpu` extends this with PCIe passthrough for an NVIDIA
GPU (RTX A2000 in this homelab). Used for the K8s worker that hosts
Jellyfin and any future GPU workloads.
