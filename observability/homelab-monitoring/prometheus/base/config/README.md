# prometheus/base/config

Prometheus server scrape configuration.

## Files

| File | Description |
|------|-------------|
| `prometheus-config.yaml` | ConfigMap (`prometheus-config`) containing the full `prometheus.yml` configuration. |

## Scrape Jobs

The configuration defines the following scrape jobs:

| Job Name | Target | Interval | Description |
|----------|--------|----------|-------------|
| `prometheus` | `localhost:9090` | 15s (default) | Prometheus self-monitoring metrics |
| `kubernetes-apiservers` | Kubernetes SD (endpoints) | 15s | API server metrics via HTTPS with service account auth. Filters for the `default/kubernetes/https` endpoint. |
| `kubernetes-nodes` | Kubernetes SD (nodes) | 15s | Node metrics proxied through the API server at `/api/v1/nodes/{node}/proxy/metrics`. |
| `kubernetes-cadvisor` | Kubernetes SD (nodes) | 15s | Container resource usage metrics via `/api/v1/nodes/{node}/proxy/metrics/cadvisor`. |
| `kubernetes-service-endpoints` | Kubernetes SD (endpoints) | 15s | Auto-discovers services with `prometheus.io/scrape: "true"` annotation. Supports custom path, port, and scheme annotations. |
| `kubernetes-pods` | Kubernetes SD (pods) | 15s | Auto-discovers pods with `prometheus.io/scrape: "true"` annotation. Supports custom path, port, and scheme annotations. |
| `traefik` | `traefik.traefik.svc.cluster.local:9100` | 15s | Traefik ingress controller metrics (static config). |
| `mktxp` | `mktxp.monitoring.svc.cluster.local:49090` | 30s | MikroTik metrics from the MKTXP exporter. Uses a 25s scrape timeout. |

## Global Settings

| Setting | Value |
|---------|-------|
| `scrape_interval` | 15s |
| `scrape_timeout` | 10s |
| `evaluation_interval` | 15s |
| External label `cluster` | `homelab` |
| External label `environment` | `production` |

## Kubernetes SD Relabeling

The service endpoints and pod scrape jobs use standard Prometheus relabel configs to extract Kubernetes metadata labels, namespace, service name, and pod name from discovered targets. Services/pods must have the annotation `prometheus.io/scrape: "true"` to be scraped.
