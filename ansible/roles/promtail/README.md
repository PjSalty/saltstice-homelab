# promtail

Installs and configures Grafana Promtail for shipping logs from VMs to Loki. Scrapes systemd journal, `/var/log/` files, and Docker container logs (on Docker hosts).

## Tasks (tasks/main.yml)

1. Clean up any existing Grafana APT sources and GPG keys
2. Download and dearmor the Grafana GPG key to `/etc/apt/keyrings/grafana.gpg`
3. Configure the Grafana APT repository
4. Install the promtail package
5. Create promtail system user and group
6. Create positions directory for offset tracking
7. Add promtail user to `systemd-journal` group (for journal access)
8. Add promtail user to `docker` group (for Docker log access, on Docker hosts)
9. Deploy promtail configuration
10. Enable and start the promtail service

## Variables (defaults/main.yml)

| Variable | Default | Description |
|----------|---------|-------------|
| `promtail_enabled` | `true` | Enable promtail installation |
| `promtail_version` | `3.4.2` | Promtail version (actual version from all.yml SSOT) |
| `promtail_loki_url` | `http://loki.example.com/loki/api/v1/push` | Loki push endpoint |
| `promtail_scrape_journald` | `true` | Scrape systemd journal |
| `promtail_scrape_varlog` | `true` | Scrape /var/log/*.log files |
| `promtail_scrape_docker` | (auto-detected) | Scrape Docker container logs (true for Docker/infrastructure/amp/vpn groups) |
| `promtail_hostname` | `{{ inventory_hostname }}` | Hostname label for logs |
| `promtail_vlan` | `{{ vlan_id }}` | VLAN label for logs |
| `promtail_positions_path` | `/var/lib/promtail/positions.yaml` | File tracking read offsets |
| `promtail_apt_repo` | `https://apt.grafana.com` | Grafana APT repository URL |
| `promtail_apt_key` | `https://apt.grafana.com/gpg.key` | Grafana GPG key URL |

## Templates

| File | Destination | Description |
|------|-------------|-------------|
| `promtail.yml.j2` | `/etc/promtail/config.yml` | Promtail config: server, clients, scrape_configs |

### Scrape Jobs

- **journal** -- Systemd journal with unit and priority labels
- **varlog** -- Static `/var/log/*.log` file scraping
- **Docker** -- Docker container JSON logs with Docker pipeline stage

All scrape jobs include `hostname` and `vlan` labels for filtering in Grafana/Loki.

## Handlers

- `Restart promtail` -- Restarts the promtail service

## Tags

`promtail`, `packages`, `config`
