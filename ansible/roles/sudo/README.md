# sudo

Minimal privilege sudo configuration. Deploys a hardened sudoers file with per-group command allowlists, restricting the Debian user to only the specific commands needed for their host group.

## Tasks (tasks/main.yml)

1. Install sudo
2. Deploy hardened sudoers config at `/etc/sudoers.d/99-hardened` (validated with `visudo -cf`)
3. Set `/etc/sudoers.d/` directory permissions to 0750

## Variables (defaults/main.yml)

| Variable | Default | Description |
|----------|---------|-------------|
| `sudo_user` | `debian` | User receiving sudo privileges |
| `sudo_base_commands` | `systemctl status, journalctl` | Commands allowed on all hosts |
| `sudo_extra_commands` | `[]` | Per-group additional commands (override in group_vars) |

### Per-Group Command Allowlists

- **infrastructure**: Docker, Docker-compose, systemctl Docker, UFW, fail2ban-client
- **k8s_cluster**: crictl, ctr, RKE2, systemctl RKE2-*, UFW, fail2ban-client
- **load_balancers**: systemctl HAProxy/keepalived, UFW, fail2ban-client
- **ci_runner**: Docker, systemctl Docker/GitLab-runner, UFW, fail2ban-client
- **Proxmox**: root user (no sudo needed)

## Templates

| File | Destination | Description |
|------|-------------|-------------|
| `sudoers-hardened.j2` | `/etc/sudoers.d/99-hardened` | Hardened sudoers: env_reset, use_pty, secure_path, NOPASSWD commands |

### Sudo Hardening Settings

- `env_reset` -- Clear environment on sudo
- `use_pty` -- Require PTY allocation (disabled for automation user)
- `secure_path` -- Restricted PATH
- `logfile` -- Sudo logging to `/var/log/sudo.log`
- `timestamp_timeout=5` -- 5-minute sudo credential cache

## Tags

`sudo`, `packages`, `hardening`
