# fail2ban

Brute force protection using fail2ban with UFW ban action integration. Monitors SSH login attempts and bans offending IPs via UFW rules.

## Tasks (tasks/main.yml)

1. Install fail2ban
2. Deploy jail configuration from template
3. Enable and start the fail2ban service

## Variables (defaults/main.yml)

| Variable | Default | Description |
|----------|---------|-------------|
| `fail2ban_enabled` | `true` | Enable fail2ban service |
| `fail2ban_maxretry` | `5` | Failed attempts before ban (overridden to 3 in all.yml) |
| `fail2ban_bantime` | `3600` | Ban duration in seconds (1 hour) |
| `fail2ban_findtime` | `600` | Window for counting failures (10 minutes) |
| `fail2ban_ignoreip` | `127.0.0.1/8 ::1 <vlan-cidr> <vlan-cidr>` | IPs excluded from banning |

## Templates

| File | Destination | Description |
|------|-------------|-------------|
| `jail.local.j2` | `/etc/fail2ban/jail.local` | Jail config: sshd filter, systemd backend, UFW banaction |

## Handlers

- `Restart fail2ban` -- Restarts the fail2ban service

## Tags

`fail2ban`, `packages`
