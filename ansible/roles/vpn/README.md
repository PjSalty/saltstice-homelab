# vpn

Deploys a WireGuard VPN server using wg-easy (Docker container with web UI). Provides secure remote access to the homelab network.

## Tasks (tasks/main.yml)

1. Create WireGuard data directory (mode 0700)
2. Check for and remove legacy `wg-easy` container (pre-compose migration)
3. Deploy Docker Compose file from template
4. Start wg-easy containers via docker_compose_v2

## Variables (defaults/main.yml)

| Variable | Default | Description |
|----------|---------|-------------|
| `vpn_wgeasy_version` | `15` | wg-easy Docker image version |
| `vpn_data_dir` | `/data/wireguard` | WireGuard data directory |
| `vpn_wg_port` | `51820` | WireGuard UDP listen port |
| `vpn_ui_port` | `51821` | wg-easy Web UI port |
| `vpn_fqdn` | `vpn.example.com` | VPN hostname |
| `vpn_password_hash` | (from SOPS) | Password hash for wg-easy UI |
| `vpn_address_range` | `<vlan-cidr>` | WireGuard client address range |
| `vpn_dns` | `<internal-ip>` | DNS server for VPN clients (AdGuard) |
| `vpn_allowed_ips` | `<internal-ip>/16, <mgmt-ip>/24` | Client allowed IPs (homelab subnets) |

## Templates

| File | Destination | Description |
|------|-------------|-------------|
| `docker-compose.yml.j2` | `/data/wireguard/docker-compose.yml` | wg-easy container: NET_ADMIN + SYS_MODULE caps, ip_forward sysctl |

## Tags

`vpn`, `config`

## Dependencies

Requires the `docker` role to be applied first.
