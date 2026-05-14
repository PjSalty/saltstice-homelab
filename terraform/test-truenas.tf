# =============================================================================
# Test TrueNAS SCALE VM — Acceptance testing for terraform-provider-truenas
# VMID 106 | <internal-ip> | VLAN 20 (Infrastructure)
# TrueNAS SCALE 25.04.2.6 (matches production version)
# IP: <internal-ip> — configure static via TrueNAS web UI after install
#
# After terraform apply:
#   1. Upload TrueNAS ISO via Proxmox UI: local → ISO Images → Download from URL
#      https://download.sys.truenas.net/TrueNAS-SCALE-Fangtooth/25.04.2.6/TrueNAS-SCALE-25.04.2.6.iso
#   2. Attach ISO to VM 106: Hardware → Add → CD/DVD → select ISO
#   3. Set boot order: Options → Boot Order → ide2 first
#   4. Boot from ISO, run installer (5 clicks)
#   5. Reboot, set admin password via web UI at https://<internal-ip>
#   6. Create API key: System → API Keys → Add
#   7. Create test pool: Storage → Create Pool → "test" (mirror of 2x 20GB)
#   8. Run acceptance tests:
#      export TRUENAS_URL=https://<internal-ip>
#      export TRUENAS_API_KEY=<key-from-step-4>
#      export TRUENAS_TEST_POOL=test
#      cd terraform-provider-truenas && make testacc
# =============================================================================

resource "proxmox_virtual_environment_vm" "test_truenas" {
  name        = "test-truenas"
  description = "Test TrueNAS SCALE for provider acceptance testing — expendable"
  tags        = ["test", "truenas", "terraform-provider"]
  node_name   = var.proxmox_node
  vm_id       = 106

  # Boot from disk — attach ISO manually for initial install
  boot_order = ["scsi0"]
  started    = true

  cpu {
    cores = 2
    type  = "host"
  }

  memory {
    dedicated = 8192 # 8GB — TrueNAS minimum
  }

  # OS boot disk
  disk {
    datastore_id = "local-zfs"
    interface    = "scsi0"
    size         = 32
    iothread     = true
    ssd          = true
    discard      = "on"
  }

  # Test pool disk 1 (will form a mirror)
  disk {
    datastore_id = "local-zfs"
    interface    = "scsi1"
    size         = 20
    iothread     = true
    ssd          = true
    discard      = "on"
  }

  # Test pool disk 2 (mirror pair)
  disk {
    datastore_id = "local-zfs"
    interface    = "scsi2"
    size         = 20
    iothread     = true
    ssd          = true
    discard      = "on"
  }

  # TrueNAS ISO: attach manually via Proxmox UI before first boot
  # Removed download_file: Proxmox host can't reach external URLs

  # Infrastructure VLAN 20
  network_device {
    bridge  = "vmbr1"
    model   = "virtio"
    vlan_id = 20
  }

  operating_system {
    type = "l26"
  }

  vga {
    type = "std"
  }

  scsi_hardware = "virtio-scsi-single"

  # No cloud-init — TrueNAS has its own installer
  # No prevent_destroy — this is a test VM
  lifecycle {
    ignore_changes = [
      cdrom,      # Attached manually for install
      started,    # May be stopped for maintenance
      boot_order, # Changes after ISO install
    ]
  }
}
