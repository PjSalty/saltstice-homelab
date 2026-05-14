# prometheus/base

Base Kustomization for the Prometheus server and its supporting resources.

## Files

| File | Description |
|------|-------------|
| `kustomization.yaml` | Lists all resources and applies labels `app.kubernetes.io/name: prometheus` and `app.kubernetes.io/component: monitoring`. |
| `namespace.yaml` | Defines the `monitoring` namespace with Pod Security Standards set to `privileged` (required for node-exporter DaemonSet host access). |

## Subdirectories

| Directory | Description |
|-----------|-------------|
| `config/` | Prometheus scrape configuration ConfigMap with jobs for self-monitoring, Kubernetes API, nodes, cAdvisor, service endpoints, pods, Traefik, and MKTXP. |
| `deployment/` | Prometheus server Deployment with ConfigMap-reload sidecar for automatic config reloading. |
| `ingress/` | TLS certificate and Traefik Ingress for `metrics.example.com`. |
| `rbac/` | ServiceAccount, ClusterRole (read access to nodes, services, endpoints, pods, ingresses, and /metrics), and ClusterRoleBinding. |
| `rules/` | PrometheusRule CRDs defining alert rules for infrastructure, SLOs, and Trivy security scanning. |
| `service/` | ClusterIP Service exposing Prometheus on port 9090. |
| `servicemonitors/` | ServiceMonitor CRDs for Kubernetes API server, kubelet, and cAdvisor metrics. |
| `storage/` | 50Gi PersistentVolumeClaim using `nfs-client` storage class. |

See individual subdirectory READMEs for detailed file descriptions.
