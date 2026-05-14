# GitLab

Deploys GitLab CE as a Docker Compose service. Manages directory structure, Docker Compose file, and container lifecycle.

## Tasks (tasks/main.yml)

1. Create GitLab directories (config, ssl, logs, data)
2. Deploy Docker Compose file from template
3. Start GitLab containers via docker_compose_v2

## Variables (defaults/main.yml)

| Variable | Default | Description |
|----------|---------|-------------|
| `gitlab_version` | `18.5.2-ce.0` | GitLab CE Docker image tag (SSOT version in all.yml) |
| `gitlab_data_dir` | `/data/gitlab` | Root data directory |
| `gitlab_config_dir` | `/data/gitlab/config` | GitLab configuration directory |
| `gitlab_logs_dir` | `/data/gitlab/logs` | GitLab log directory |
| `gitlab_data_storage` | `/data/gitlab/data` | GitLab persistent data |
| `gitlab_ssh_port` | `2222` | Git SSH port (avoids conflict with host SSH on 22) |
| `gitlab_fqdn` | `gitlab.example.com` | GitLab hostname |

## Templates

| File | Destination | Description |
|------|-------------|-------------|
| `docker-compose.yml.j2` | `/data/gitlab/docker-compose.yml` | GitLab CE container: ports 80/443/2222, OMNIBUS_CONFIG inline |

### GitLab OMNIBUS Configuration

Set via the `GITLAB_OMNIBUS_CONFIG` environment variable:
- External URL: `https://gitlab.example.com`
- HTTPS redirect enabled
- SSL certificate paths configured for cert-manager deployed certs
- Git SSH port: 2222
- Timezone: from global `timezone` variable

## Tags

`gitlab`, `config`

## Dependencies

Requires the `docker` role to be applied first.

## Notes

GitLab CE requires sequential minor version upgrades. Check the [upgrade path](https://docs.gitlab.com/ee/update/#upgrade-paths) before changing `gitlab_version`.
