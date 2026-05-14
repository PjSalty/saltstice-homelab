# Harbor

Deploys Harbor container registry via the offline installer. Manages configuration, robot account bootstrapping, project creation, proxy cache registries, and vulnerability scanning policies.

## Tasks (tasks/main.yml)

1. Create Harbor directories (data, install, logs, certs)
2. Download Harbor offline installer from GitHub releases
3. Extract installer archive
4. Deploy Harbor configuration from template
5. Run Harbor installer (first install only, checks for existing containers)
6. Make sure Harbor containers are running via Docker Compose
7. Flush handlers (applies config changes via `prepare` + restart)
8. Wait for Harbor API to be healthy (retries for up to 3 minutes)
9. Bootstrap automation robot account (system-level, with push/pull/list permissions)
10. Create standard projects (infrastructure, tools)
11. Create registry endpoints for proxy cache (Docker Hub, GHCR, GCR)
12. Create proxy cache projects backed by registry endpoints
13. Enable auto-scan and vulnerability prevention on all projects

## Variables (defaults/main.yml)

| Variable | Default | Description |
|----------|---------|-------------|
| `harbor_version` | `2.12.2` | Harbor version (SSOT in all.yml) |
| `harbor_data_dir` | `/data/harbor` | Root data directory |
| `harbor_install_dir` | `/data/harbor/install` | Installer location |
| `harbor_data_storage` | `/data/harbor/data` | Persistent storage |
| `harbor_log_dir` | `/data/harbor/logs` | Log directory |
| `harbor_cert_dir` | `/data/harbor/secret/cert` | TLS certificate directory |
| `harbor_fqdn` | `harbor.example.com` | Harbor hostname |
| `harbor_admin_password` | (from SOPS) | Admin password |
| `harbor_db_password` | (from SOPS) | PostgreSQL database password |
| `harbor_robot_secret` | (from SOPS) | Automation robot account secret |
| `harbor_robot_name` | `robot$<svc-account>` | Robot account name |
| `harbor_projects` | `[infrastructure, tools]` | Standard projects to create |
| `harbor_proxy_cache_projects` | (list) | Proxy cache project definitions |

### Proxy Cache Projects

| Name | Registry URL | Type |
|------|-------------|------|
| `dockerhub-proxy` | `https://hub.docker.com` | Docker-hub |
| `ghcr-proxy` | `https://ghcr.io` | GitHub-ghcr |
| `gcr-proxy` | `https://gcr.io` | google-gcr |

## Templates

| File | Destination | Description |
|------|-------------|-------------|
| `harbor.yml.j2` | `/data/harbor/install/harbor/harbor.yml` | Harbor core config: HTTPS, DB, Trivy, logging, upload purging |

## Handlers

- `Reconfigure Harbor` -- Runs `./prepare` to regenerate Docker Compose from Harbor.yml
- `Restart Harbor` -- Restarts all Harbor containers via Docker Compose

## Tags

`harbor`, `config`, `harbor-api`, `projects`, `proxy-cache`, `scanning`

## Dependencies

Requires the `docker` role to be applied first.

## Security Notes

- Harbor uses OIDC auth; basic auth is enabled only for robot account bootstrapping
- All API calls after bootstrap use the robot account Bearer token
- Auto-scan and critical vulnerability prevention are enforced on all projects
