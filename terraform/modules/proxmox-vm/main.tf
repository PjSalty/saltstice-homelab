terraform {
  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "~> 0.106.0"
    }
  }
}

resource "proxmox_virtual_environment_vm" "vm" {
  name        = var.vm_name
  description = var.vm_description
  tags        = var.tags
  node_name   = var.node_name
  vm_id       = var.vm_id

  scsi_hardware = "virtio-scsi-single"

  clone {
    vm_id = var.template_vm_id
    full  = true
  }

  agent {
    enabled = false
    timeout = "1s"
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
    # Keep Terraform from fighting Proxmox GUI / Ansible / cosmetic
    # drift. VM restarts on these are unnecessary (VGA alone is 15+
    # minutes). Configurable attributes only — computed ones have
    # no effect here.
    ignore_changes = [
      clone,
      initialization,
      cdrom,
      started,
      agent,
      network_device,
      serial_device,
      startup,
      disk[0].iothread,
      scsi_hardware,
      vga,
      keyboard_layout,
      tags,
      description,
      on_boot,
      migrate,
      protection,
      stop_on_destroy,
      rng,
    ]
  }
}
