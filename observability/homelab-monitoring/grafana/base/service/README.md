# grafana/base/service

Kubernetes Service for the Grafana server.

## Files

| File | Description |
|------|-------------|
| `service.yaml` | ClusterIP Service (`grafana`) exposing port 3000. Selects pods with labels `app: grafana, component: visualization`. |

## Service Details

| Property | Value |
|----------|-------|
| Name | `grafana` |
| Type | ClusterIP |
| Port | 3000 (TCP) |
| Target Port | 3000 |
| Selector | `app: grafana, component: visualization` |
