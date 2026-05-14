# common

Base OS configuration applied to all managed hosts. Installs essential packages, configures timezone, locale, sysctl hardening, NTP, DNS resolvers, and Prometheus node_exporter.

## Tasks (tasks/main.yml)

1. Set timezone and locale
2. Update apt cache and install base packages
3. Apply sysctl kernel hardening parameters
4. Disable swap (remove from fstab)
5. Disable OpenSSL post-quantum key exchange (breaks MikroTik TLS inspection)
6. Configure DNS resolvers via `/etc/resolv.conf`
7. Configure chrony NTP and enable the service
8. Install and configure prometheus-node-exporter

## Variables (defaults/main.yml)

| Variable | Default | Description |
|----------|---------|-------------|
| `common_packages` | (list of ~25 packages) | Base packages: curl, jq, htop, vim, tmux, git, chrony, etc. |
| `common_sysctl` | (dict) | Kernel parameters: ip_forward, swappiness, inotify, kptr_restrict, etc. |
| `common_disable_swap` | `true` | Disable swap and remove from fstab |
| `common_openssl_disable_pq` | `true` | Disable post-quantum key exchange (X25519MLKEM768) |
| `common_openssl_groups` | `X25519:P-256:P-384` | Allowed TLS key exchange groups |

### Global Variables (from group_vars/all.yml)

| Variable | Default | Description |
|----------|---------|-------------|
| `timezone` | `America/Chicago` | System timezone |
| `locale` | `en_US.UTF-8` | System locale |
| `dns_servers` | `[<internal-ip>, 1.1.1.1]` | DNS resolvers (AdGuard + Cloudflare) |
| `ntp_servers` | `[0.pool.ntp.org, 1.pool.ntp.org]` | NTP servers |
| `node_exporter_enabled` | `true` | Install prometheus-node-exporter |
| `node_exporter_port` | `9100` | node_exporter listen port |

## Templates

| File | Destination | Description |
|------|-------------|-------------|
| `chrony.conf.j2` | `/etc/chrony/chrony.conf` | Chrony NTP configuration with configured servers |
| `resolv.conf.j2` | `/etc/resolv.conf` | DNS resolver configuration with search domain |

## Handlers

- `Restart chrony` -- Restarts the chrony NTP service
- `Restart node_exporter` -- Restarts prometheus-node-exporter

## Tags

`common`, `packages`, `timezone`, `locale`, `sysctl`, `swap`, `openssl`, `tls`, `dns`, `ntp`, `monitoring`, `node-exporter`

## Dependencies

None. This role is applied first on all hosts.
