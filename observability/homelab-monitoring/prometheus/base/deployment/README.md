# prometheus/base/deployment

Prometheus server Deployment definition.

## Files

| File | Description |
|------|-------------|
| `deployment.yaml` | Deployment (`prometheus`) running the Prometheus server with a ConfigMap-reload sidecar. |

## Containers

### prometheus (main)

- **Image**: `${IMAGE_PROMETHEUS}` (variable substituted by Flux/Kustomize)
- **Port**: 9090 (web UI and API)
- **Storage**: Data stored at `/prometheus` via the `prometheus-data` PVC
- **Config**: Mounted from the `prometheus-config` ConfigMap at `/etc/prometheus`
- **Retention**: 15 days or 45GB (whichever is reached first)
- **Features**: Lifecycle API and admin API enabled for runtime config reloads and data management
- **Resources**: 500m-2000m CPU, 1Gi-4Gi memory
- **Probes**: Liveness at `/-/healthy` (60s initial, 60s period), readiness at `/-/ready` (15s initial, 30s period)

### ConfigMap-reload (sidecar)

- **Image**: `${IMAGE_CONFIGMAP_RELOAD}`
- **Purpose**: Watches `/etc/prometheus` for ConfigMap changes and triggers a reload via `POST /-/reload`
- **Resources**: 10m-50m CPU, 16Mi-32Mi memory

## Security Context

- Runs as non-root user 65534 (nobody)
- `fsGroup: 65534` for volume permissions
- Uses the `prometheus` ServiceAccount for Kubernetes API access

## Strategy

Uses `Recreate` strategy since Prometheus uses a PVC that cannot be shared between pods.
