# NetBox

Deploys NetBox (network documentation and IPAM) as a Docker Compose stack with PostgreSQL and Redis backends.

## Tasks (tasks/main.yml)

1. Create NetBox directories (Postgres-data, Redis-data, media, reports, scripts)
2. Deploy Docker Compose file from template
3. Deploy environment file with credentials from SOPS SSOT
4. Start NetBox containers via docker_compose_v2

## Variables (defaults/main.yml)

| Variable | Default | Description |
|----------|---------|-------------|
| `netbox_version` | `4.2.6` | NetBox Docker image version |
| `netbox_data_dir` | `/data/netbox` | Root data directory |
| `netbox_fqdn` | `netbox.example.com` | NetBox hostname |
| `netbox_db_name` | `netbox` | PostgreSQL database name |
| `netbox_db_user` | `netbox` | PostgreSQL username |
| `netbox_superuser_name` | `admin` | Initial superuser username |
| `netbox_superuser_email` | `admin@example.com` | Superuser email |
| `netbox_login_required` | `true` | Require login for all access |
| `netbox_metrics_enabled` | `true` | Enable Prometheus metrics endpoint |

## Templates

| File | Destination | Description |
|------|-------------|-------------|
| `docker-compose.yml.j2` | `/data/netbox/docker-compose.yml` | NetBox stack: app, worker, housekeeping, PostgreSQL 16, Redis 7 |
| `netbox.env.j2` | `/data/netbox/.env` | Environment file with DB credentials, secret key, superuser config |

### Docker Compose Services

- **NetBox** -- Main application (ports 80/443 mapped to 8080/8443)
- **NetBox-worker** -- RQ background worker
- **NetBox-housekeeping** -- Periodic maintenance tasks
- **Postgres** -- PostgreSQL 16 with health check
- **Redis** -- Redis 7 with AOF persistence and health check

### Credentials (from SOPS SSOT)

- `creds.infrastructure.netbox.db_password`
- `creds.infrastructure.netbox.secret_key`
- `creds.infrastructure.netbox.admin_password`
- `creds.infrastructure.netbox.api_token`

## Handlers

- `Restart netbox` -- Restarts the NetBox Docker Compose stack

## Tags

`netbox`, `config`

## Dependencies

Requires the `docker` role to be applied first.
