# Proxmox

Proxmox VE hypervisor hardening and performance tuning. Configures IOMMU for GPU passthrough, kernel module blacklists, ZFS ARC tuning, SSD i/O scheduler, and static routing for Traefik.

## Tasks (tasks/main.yml)

1. Disable Proxmox enterprise repository, enable no-subscription repo
2. Blacklist kernel modules for GPU passthrough (nouveau, snd_hda_intel, snd_hda_codec_hdmi)
3. Configure IOMMU kernel parameters in GRUB
4. Load VFIO modules (vfio, vfio_iommu_type1, vfio_pci, vfio_virqfd)
5. Apply Proxmox-specific sysctl settings (network buffers, bridge-nf-call disabled, memory management)
6. Set ZFS ARC maximum (32GB)
7. Apply ZFS atime=off and autotrim=on on rpool
8. Add static route to Traefik VIP via K8s VLAN (bypasses MikroTik conntrack/fasttrack)
9. Set SSD i/O scheduler to `none` and persist via udev rule

## Variables (defaults/main.yml)

| Variable | Default | Description |
|----------|---------|-------------|
| `proxmox_iommu_enabled` | `true` | Enable IOMMU for GPU passthrough |
| `proxmox_enterprise_repo` | `false` | Use enterprise repo (requires subscription) |
| `proxmox_grub_cmdline` | `quiet intel_iommu=on iommu=pt` | GRUB kernel parameters |
| `proxmox_blacklist_modules` | `[nouveau, snd_hda_intel, snd_hda_codec_hdmi]` | Modules to blacklist |
| `proxmox_zfs_arc_max_gb` | `32` | ZFS ARC max in GB (for 252GB host) |
| `proxmox_zfs_atime` | `off` | ZFS atime setting |
| `proxmox_zfs_autotrim` | `true` | Enable ZFS SSD TRIM |
| `proxmox_ssd_devices` | `[sdm, sdn]` | SSD block devices for i/O scheduler tuning |
| `proxmox_traefik_vip` | `<internal-ip>` | Traefik MetalLB VIP |
| `proxmox_traefik_gateway` | `10.x0.20` | K8s worker for Traefik routing |
| `proxmox_traefik_dev` | `vmbr1.30` | Network interface for Traefik route |
| `proxmox_traefik_src` | `10.x0.100` | Source IP for Traefik route |

### Sysctl Highlights

- `net.bridge.bridge-nf-call-iptables: 0` -- Disables bridge netfilter (prevents UFW from blocking inter-VM traffic)
- `vm.swappiness: 1` -- Minimal swap usage on hypervisor
- `vm.min_free_kbytes: 1048576` -- Reserve 1GB free memory
- 10G network buffer tuning (rmem/wmem 16MB)

## Templates

| File | Destination | Description |
|------|-------------|-------------|
| `module-blacklist.conf.j2` | `/etc/modprobe.d/blacklist-homelab.conf` | Module blacklist for GPU passthrough |

## Tags

`proxmox`, `packages`, `gpu`, `iommu`, `sysctl`, `zfs`, `performance`, `network`, `routing`
