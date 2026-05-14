# Tempo Distributed Tracing

Grafana Tempo backend for distributed trace collection and querying. Deployed as a standalone (non-Helm) Deployment with NFS-backed persistence.

Deployed by the `tempo` Flux Kustomization from `clusters/homelab/infrastructure-kustomizations.yaml`, which depends on `nfs-storage`.

## Directory Structure

```
tempo/
  base/
    kustomization.yaml     # Aggregates all resources
    namespace.yaml         # Namespace with restricted PSA
    configmap.yaml         # Tempo configuration (storage, retention, receivers)
    deployment.yaml        # Tempo Deployment
    service.yaml           # ClusterIP services for OTLP, Jaeger, and Zipkin receivers
    pvc.yaml               # NFS PersistentVolumeClaim for trace storage
    networkpolicy.yaml     # CiliumNetworkPolicy for trace ingestion
    servicemonitor.yaml    # Prometheus ServiceMonitor for Tempo metrics
    autoscaling/
      vpa.yaml             # VPA in Auto mode
```

## Trace Ingestion

Tempo accepts traces via multiple protocols:

| Protocol | Port | Service |
|----------|------|---------|
| OTLP gRPC | 4317 | `tempo.tempo.svc` |
| OTLP HTTP | 4318 | `tempo.tempo.svc` |
| Jaeger Thrift HTTP | 14268 | `tempo.tempo.svc` |
| Zipkin | 9411 | `tempo.tempo.svc` |

## Integration

- **Grafana** queries Tempo via its datasource configuration for trace visualization
- **Prometheus** scrapes Tempo metrics via the ServiceMonitor
- Applications instrumented with OpenTelemetry send traces to Tempo's OTLP endpoint

## Kustomization

```yaml
resources:
  - namespace.yaml
  - configmap.yaml
  - deployment.yaml
  - service.yaml
  - pvc.yaml
  - networkpolicy.yaml
  - servicemonitor.yaml
  - autoscaling
```
