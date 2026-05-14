# ntfy

Push notification service used as the primary alerting channel for the homelab. AlertManager sends all alerts to ntfy (Discord has been fully removed).

## FQDN

`https://ntfy.example.com`

## Namespace

`ntfy`

## Directory Structure

```
base/
  kustomization.yaml              - Kustomize manifest listing all resources
  namespace.yaml                  - Namespace with PSA restricted enforcement
  deployments/
    deployment.yaml               - ntfy Deployment (1 replica)
  services/
    service.yaml                  - ClusterIP Service on port 80
  ingress/
    ingress.yaml                  - Traefik Ingress with wildcard TLS
  storage/
    pvc.yaml                      - 1Gi NFS PVC for cache database
  autoscaling/
    kustomization.yaml            - Lists VPA resource
    vpa.yaml                      - VPA in Auto mode (10m-250m CPU, 32Mi-256Mi memory)
```

## Key Configuration

### Deployment

- **Image**: Managed via Flux variable substitution (`${IMAGE_NTFY}`)
- **Replicas**: 1
- **Command**: `serve`
- **Security**: runAsNonRoot (UID 1000), all capabilities dropped, readOnlyRootFilesystem disabled (ntfy needs cache writes)

### Environment Variables

| Variable | Value | Purpose |
|----------|-------|---------|
| `NTFY_BASE_URL` | `https://ntfy.example.com` | Public URL for notification links |
| `NTFY_CACHE_FILE` | `/var/cache/ntfy/cache.db` | SQLite cache location |
| `NTFY_BEHIND_PROXY` | `true` | Trust X-Forwarded headers from Traefik |
| `NTFY_UPSTREAM_BASE_URL` | `https://ntfy.sh` | Upstream for mobile push delivery |

### Probes

- **Liveness**: HTTP GET `/v1/health` (initial delay 10s, period 30s)
- **Readiness**: HTTP GET `/v1/health` (initial delay 5s, period 10s)

## Storage

- **Cache PVC**: 1Gi on `nfs-client` StorageClass, stores message cache in SQLite

## Autoscaling

- **VPA**: Auto mode for both CPU (10m-250m) and memory (32Mi-256Mi)
- **No HPA**: Single-instance stateful service

## Pod Security

Namespace enforces `restricted` Pod Security Admission. Goldilocks is enabled for resource recommendations.

## Dependencies

- Wildcard TLS certificate from cert-manager (`wildcard-tls`)
- AlertManager configured to send to `homelab-saltstice-critical` topic on ntfy.sh
