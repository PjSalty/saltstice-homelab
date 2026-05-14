# grafana/base

Base Kustomization for the standalone Grafana deployment. Includes all resources needed to run Grafana independently of the kube-prometheus-stack HelmRelease.

## Files

| File | Description |
|------|-------------|
| `kustomization.yaml` | Lists all resources and uses `configMapGenerator` to create `grafana-dashboards-files` from the 6 JSON dashboard files. Applies labels `app.kubernetes.io/name: grafana` and `app.kubernetes.io/component: monitoring`. |

## Subdirectories

| Directory | Description |
|-----------|-------------|
| `config/` | Grafana server configuration (`grafana.ini`), datasource definitions (Prometheus + Loki), and dashboard provider configuration. |
| `dashboards/` | Six Grafana dashboard JSON files covering Kubernetes cluster, node exporter, Traefik, security overview, Kubernetes audit, and Trivy vulnerabilities. |
| `deployment/` | Grafana server Deployment with volume mounts for config, dashboards, datasources, and secrets. |
| `ingress/` | TLS certificate and Traefik Ingress for `grafana.example.com`. |
| `jobs/` | One-time Job that validates dashboard file availability after deployment. |
| `secrets/` | SOPS-encrypted Secret containing Grafana admin username, password, and Authentik OIDC client secret. |
| `service/` | ClusterIP Service exposing Grafana on port 3000. |
| `storage/` | 10Gi PersistentVolumeClaim using `nfs-client` storage class. |

See individual subdirectory READMEs for detailed file descriptions.
