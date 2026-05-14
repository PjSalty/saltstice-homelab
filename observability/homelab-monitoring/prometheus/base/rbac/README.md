# prometheus/base/RBAC

RBAC resources granting the Prometheus server access to Kubernetes API resources for service discovery and metrics scraping.

## Files

| File | Description |
|------|-------------|
| `serviceaccount.yaml` | ServiceAccount (`prometheus`) in the `monitoring` namespace. Used by the Prometheus Deployment. |
| `clusterrole.yaml` | ClusterRole (`prometheus`) granting read-only access (`get`, `list`, `watch`) to nodes, node proxies, node metrics, services, endpoints, pods, ConfigMaps, and ingresses. Also grants `get` on non-resource URLs `/metrics` and `/metrics/cadvisor`. |
| `clusterrolebinding.yaml` | ClusterRoleBinding (`prometheus`) binding the `prometheus` ClusterRole to the `prometheus` ServiceAccount in the `monitoring` namespace. |

## Permissions Summary

| Resource | Verbs | Purpose |
|----------|-------|---------|
| nodes, nodes/proxy, nodes/metrics | get, list, watch | Node-level metrics and cAdvisor proxying |
| services, endpoints, pods | get, list, watch | Kubernetes service discovery for scrape targets |
| ConfigMaps | get | Configuration access |
| ingresses (networking.K8s.io) | get, list, watch | Ingress discovery |
| /metrics, /metrics/cadvisor | get | Non-resource URL access for scraping |
