# GitLab-runner

Installs and configures a GitLab Runner with Docker executor and host networking for reliable cross-VLAN SSH access during deploy jobs.

## Tasks (tasks/main.yml)

1. Download and dearmor GitLab Runner GPG key
2. Configure GitLab Runner APT repository (Debian Trixie)
3. Install GitLab Runner at pinned version
4. Pin GitLab Runner version via APT preferences (prevents auto-upgrade)
5. Make sure automation SSH directory exists
6. Deploy GitLab Runner configuration from template
7. Enable and start the GitLab-runner service

## Variables (defaults/main.yml)

| Variable | Default | Description |
|----------|---------|-------------|
| `gitlab_runner_version` | `18.8.0` | Runner version (SSOT in all.yml: 18.10.0) |
| `gitlab_url` | `https://gitlab.example.com` | GitLab instance URL |
| `gitlab_runner_executor` | `docker` | Executor type |
| `gitlab_runner_concurrent` | `4` | Maximum concurrent jobs |
| `gitlab_runner_check_interval` | `3` | Seconds between job polling |
| `gitlab_runner_tag_list` | `deploy,infrastructure,terraform` | Runner tags |
| `gitlab_runner_run_untagged` | `false` | Accept untagged jobs |
| `gitlab_runner_description` | `Dedicated Deploy Runner (hostname)` | Runner description |
| `gitlab_runner_docker_image` | `harbor.example.com/tools/ansible-runner:stable` | Default Docker image |
| `gitlab_runner_docker_network_mode` | `host` | Docker network mode (host for SSH access) |
| `gitlab_runner_docker_privileged` | `false` | Docker privileged mode |
| `gitlab_runner_docker_pull_policy` | `if-not-present` | Image pull policy |
| `gitlab_runner_docker_volumes` | `["/etc/gitlab-runner/ssh:..."]` | Volume mounts for SSH keys |
| `gitlab_runner_metrics_port` | `9252` | Prometheus metrics port |

## Templates

| File | Destination | Description |
|------|-------------|-------------|
| `config.toml.j2` | `/etc/gitlab-runner/config.toml` | Runner config: executor, Docker settings, allowed images, output limit |

### Key Configuration

- **Host networking**: Enables direct SSH from CI jobs to infrastructure VMs across VLANs
- **SSH key volume**: Mounts `/etc/gitlab-runner/ssh` read-only into containers
- **Allowed images**: Only Harbor images (`harbor.example.com/*`)
- **Output limit**: 50MB (handles verbose Ansible output)

## Handlers

- `Restart gitlab-runner` -- Restarts the GitLab-runner service

## Tags

`gitlab-runner`, `packages`, `config`

## Dependencies

Requires the `docker` role to be applied first.

## Notes

The runner token is set after manual registration via `gitlab-runner register`. The template includes a placeholder comment for the token.
