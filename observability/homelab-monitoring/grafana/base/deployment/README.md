# grafana/base/deployment

Grafana server Deployment definition.

## Files

| File | Description |
|------|-------------|
| `deployment.yaml` | Deployment (`grafana`) running the Grafana server with multiple volume mounts for configuration, dashboards, datasources, and secrets. |

## Container Details

- **Image**: `${IMAGE_GRAFANA}` (variable substituted by Flux/Kustomize)
- **Port**: 3000 (HTTP)
- **Resources**: 250m-1000m CPU, 512Mi-2Gi memory
- **Probes**: Liveness and readiness at `/api/health` on port 3000

## Volume Mounts

| Mount Path | Source | Content |
|------------|--------|---------|
| `/etc/grafana` | ConfigMap `grafana-config` | `grafana.ini` configuration |
| `/var/lib/grafana` | PVC `grafana-data` | Persistent data (SQLite DB, plugins) |
| `/var/lib/grafana/dashboards` | ConfigMap `grafana-dashboards-files` | Dashboard JSON files |
| `/etc/grafana/provisioning/datasources` | ConfigMap `grafana-datasources` | Datasource definitions |
| `/etc/grafana/provisioning/dashboards` | ConfigMap `grafana-dashboard-provider` | Dashboard provider config |
| `/etc/secrets` (read-only) | Secret `grafana-admin-secret` | Admin password and OIDC secret |

## Environment Variables

| Variable | Value | Purpose |
|----------|-------|---------|
| `GF_PATHS_CONFIG` | `/etc/grafana/grafana.ini` | Config file location |
| `GF_PATHS_DATA` | `/var/lib/grafana` | Data directory |
| `GF_PATHS_LOGS` | `/var/log/grafana` | Log directory |
| `GF_PATHS_PLUGINS` | `/var/lib/grafana/plugins` | Plugin directory |
| `GF_PATHS_PROVISIONING` | `/etc/grafana/provisioning` | Provisioning directory |

## Security Context

- Runs as non-root user 472 (grafana)
- `fsGroup: 472` for volume permissions
- Uses `Recreate` strategy (PVC cannot be shared)
