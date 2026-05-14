# auto-updates

Configures unattended-upgrades for automatic security patches on all managed hosts.

## Tasks (tasks/main.yml)

1. Install unattended-upgrades and apt-listchanges
2. Deploy unattended-upgrades configuration
3. Enable automatic package list updates (daily) and unattended upgrades
4. Enable the unattended-upgrades service

## Variables (defaults/main.yml)

| Variable | Default | Description |
|----------|---------|-------------|
| `auto_updates_enabled` | `true` | Enable automatic updates |
| `auto_updates_type` | `security` | Update scope: `security` (security repos only) or `all` |
| `auto_updates_auto_reboot` | `false` | Automatically reboot when required |
| `auto_updates_reboot_time` | `03:00` | Reboot time (if auto_reboot is true) |
| `auto_updates_mail` | `""` | Email address for update notifications |
| `auto_updates_extra_origins` | `[]` | Additional APT origin patterns for unattended-upgrades |

### Per-Group Overrides

- **Proxmox**: `auto_updates_auto_reboot: true`, `auto_updates_reboot_time: "04:00"`, includes Proxmox PVE repository as an extra origin

## Templates

| File | Destination | Description |
|------|-------------|-------------|
| `50unattended-upgrades.j2` | `/etc/apt/apt.conf.d/50unattended-upgrades` | Origins, blacklist, auto-reboot, cleanup settings |

### APT Periodic Configuration

Created directly (not templated):
- `APT::Periodic::Update-Package-Lists "1"` -- Daily cache refresh
- `APT::Periodic::Unattended-Upgrade "1"` -- Daily upgrade check
- `APT::Periodic::AutocleanInterval "7"` -- Weekly cache cleanup

## Tags

`auto-updates`, `packages`
