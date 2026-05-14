# Loki Log Aggregation

Centralized log aggregation stack consisting of Grafana Loki (monolithic mode) and Grafana Alloy (log shipper/collector). Provides LogQL query capability for all cluster and application logs.

Deployed by the `loki` Flux Kustomization from `clusters/homelab/infrastructure-kustomizations.yaml`, which depends on `nfs-storage` for persistence.

## Files

| File | Resources | Purpose |
|------|-----------|---------|
| `helmrelease.yaml` | HelmRelease `loki` | Loki in monolithic mode (chart version from `${HELM_LOKI}`) |
| `alloy-helmrelease.yaml` | HelmRelease `alloy` | Grafana Alloy log collector (replaces Promtail) |
| `namespace.yaml` | Namespace `loki` | Namespace with baseline PSA and Goldilocks VPA enabled |
| `loki-external-service.yaml` | Service, Endpoints | Exposes Loki on MetalLB IP for external log ingestion (e.g., from VMs) |
| `logql-alerting-rules.yaml` | PrometheusRule | LogQL-based alert rules (error rate spikes, log volume anomalies) |
| `security-alerts.yaml` | PrometheusRule | Security-focused LogQL alerts (SSH brute force, privilege escalation, suspicious commands) |

### autoscaling/

| File | Resources | Purpose |
|------|-----------|---------|
| `vpa.yaml` | VerticalPodAutoscaler | VPA in Auto mode for Loki and Alloy pods |

## Architecture

```
All Pods  -->  Alloy (DaemonSet, log collection)  -->  Loki (monolithic, log storage + query)
                                                            |
VMs      -->  Loki External Service (MetalLB IP)  ----------+
                                                            |
Grafana  <--  LogQL queries  <------------------------------+
```

## Health Checks

The Flux Kustomization defines health checks for both HelmReleases:
- `loki` HelmRelease in namespace `loki`
- `alloy` HelmRelease in namespace `loki`

Both must be healthy before the Kustomization reports success.

## Kustomization

```yaml
resources:
  - namespace.yaml
  - helmrelease.yaml
  - alloy-helmrelease.yaml
  - loki-external-service.yaml
  - logql-alerting-rules.yaml
  - security-alerts.yaml
  - autoscaling
```
