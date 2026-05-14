# prometheus/base/service

Kubernetes Service for the Prometheus server.

## Files

| File | Description |
|------|-------------|
| `service.yaml` | ClusterIP Service (`prometheus`) exposing port 9090. Selects pods with labels `app: prometheus, component: server`. Annotated with `prometheus.io/scrape: "true"` for self-discovery. |

## Service Details

| Property | Value |
|----------|-------|
| Name | `prometheus` |
| Type | ClusterIP |
| Port | 9090 (TCP) |
| Target Port | 9090 |
| Selector | `app: prometheus, component: server` |
