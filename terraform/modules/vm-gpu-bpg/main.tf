# =============================================================================
# VM Module - BPG Provider (VM with GPU Passthrough)
# =============================================================================

terraform {
  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "~> 0.106.0" # Per config/versions.yaml SSOT
    }
  }
}

resource "proxmox_virtual_environment_vm" "vm_gpu" {
  name        = var.vm_name
  description = var.vm_description
  tags        = var.tags
  node_name   = var.node_name
  vm_id       = var.vm_id

  machine = "q35" # Required for PCIe passthrough

  scsi_hardware = "virtio-scsi-single"

  clone {
    vm_id = var.template_vm_id
    full  = true
  }

  agent {
    enabled = false
    timeout = "1s" # Minimal timeout since agent is disabled
  }

  cpu {
    cores = var.cpu_cores
    type  = "host"
    units = 1024
    numa  = true
  }

  memory {
    dedicated = var.memory_mb
  }

  disk {
    datastore_id = "local-zfs"
    interface    = "scsi0"
    size         = var.disk_size_gb
    iothread     = true
    ssd          = true
    discard      = "on"
  }

  network_device {
    bridge  = "vmbr1"
    model   = "virtio"
    vlan_id = var.vlan_id
  }

  # GPU passthrough using PCI mapping (required for API token authentication)
  # Mapping defined in /etc/pve/mapping/pci.cfg as "nvidia-rtx-a2000"
  hostpci {
    device  = "hostpci0"
    mapping = var.gpu_mapping_name
    pcie    = true
    rombar  = true
  }

  operating_system {
    type = "l26"
  }

  initialization {
    datastore_id = "local-zfs"

    ip_config {
      ipv4 {
        address = "${var.ip_address}/24"
        gateway = var.gateway
      }
    }

    user_account {
      username = "debian"
      keys     = [var.ssh_keys]
    }

    dns {
      servers = [var.nameserver]
    }
  }

  vga {
    type = "std"
  }

  lifecycle {
    prevent_destroy = true
    # Ignore configurable attributes managed outside Terraform (Proxmox GUI, Ansible, etc.)
    # This prevents slow apply times from cosmetic changes that require VM restarts
    # Note: Only include configurable attributes, not computed ones (they have no effect)
    # Note: machine is NOT ignored - q35 is required for GPU passthrough
    ignore_changes = [
      clone,            # Clone settings only used at creation
      initialization,   # Cloud-init only used at creation
      cdrom,            # CD-ROM may be configured via Proxmox GUI
      started,          # Running state managed externally
      agent,            # QEMU agent settings may differ
      network_device,   # Bridge config managed at Proxmox level (vmbr1 VLAN trunk)
      serial_device,    # Serial console configured via Proxmox
      startup,          # Boot order configured via Proxmox
      disk[0].iothread, # Disk iothread may differ
      scsi_hardware,    # SCSI controller type (requires VM restart)
      vga,              # VGA type changes require VM restart (15+ min)
      keyboard_layout,  # Cosmetic setting
      tags,             # May be reordered or modified via Proxmox GUI
      description,      # May be modified via Proxmox GUI
      on_boot,          # Start on boot setting
      migrate,          # Migration flag
      protection,       # Protection settings
      stop_on_destroy,  # Stop behavior
      rng,              # RNG device (requires root@pam, managed via Proxmox GUI)
    ]
  }
}
