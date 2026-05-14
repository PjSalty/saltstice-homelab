# Docker

Installs Docker CE from the official Docker repository with daemon configuration and Harbor registry mirror.

## Tasks (tasks/main.yml)

1. Install Docker prerequisites (ca-certificates, curl, gnupg)
2. Clean up any existing Docker APT sources and GPG keys
3. Download and dearmor the Docker GPG key to `/etc/apt/keyrings/docker.gpg`
4. Configure the Docker APT repository (Debian release-specific)
5. Install Docker CE packages: Docker-ce, Docker-ce-cli, containerd.io, Docker-buildx-plugin, Docker-compose-plugin
6. Deploy Docker daemon configuration from template
7. Add specified users to the Docker group
8. Enable and start the Docker service

## Variables (defaults/main.yml)

| Variable | Default | Description |
|----------|---------|-------------|
| `docker_edition` | `ce` | Docker edition |
| `docker_users` | `[debian]` | Users added to the Docker group |
| `docker_log_driver` | `json-file` | Docker log driver |
| `docker_log_max_size` | `50m` | Maximum log file size |
| `docker_log_max_file` | `3` | Maximum number of log files |
| `docker_registry_mirrors` | `["https://harbor.{{ domain }}"]` | Registry mirror URLs (Harbor proxy cache) |

## Templates

| File | Destination | Description |
|------|-------------|-------------|
| `daemon.json.j2` | `/etc/docker/daemon.json` | Daemon config: log driver, registry mirrors, overlay2 storage, live-restore |

## Handlers

- `Restart docker` -- Restarts the Docker daemon

## Tags

`docker`, `packages`, `config`

## Used By

Applied to the following host groups: infrastructure, amp_servers, vpn_servers, ci_runner.
