# grafana/base/dashboards

Grafana dashboard JSON files loaded into the standalone Grafana deployment via the `configMapGenerator` in `base/kustomization.yaml`.

## Files

| File | Grafana ID | Datasource | Description |
|------|-----------|------------|-------------|
| `kubernetes-cluster-dashboard.json` | gnetId 7249 | Prometheus | Kubernetes cluster overview: node resources, pod counts, namespace usage. Default home dashboard. |
| `node-exporter-dashboard.json` | gnetId 1860 | Prometheus | Per-node metrics from node_exporter: CPU, memory, disk i/O, network, filesystem usage. |
| `traefik-dashboard.json` | gnetId 11462 | Prometheus | Traefik ingress controller: request rates, response codes, latency by router, TLS status. |
| `security-overview-dashboard.json` | Custom | Loki | SIEM-style security dashboard: failed auth attempts, sudo commands, permission denials, OOM events. Queries Loki logs. |
| `kubernetes-audit-dashboard.json` | Custom | Loki | Kubernetes operational issues: RBAC denials, CrashLoopBackOff events, image pull failures, OOM kills. Queries Loki logs. |
| `trivy-vulnerability-dashboard.json` | Custom | Prometheus | Container vulnerability scanning: CVE counts by severity (Critical/High/Medium/Low), vulnerabilities by namespace, trend over time. Uses `trivy_image_vulnerabilities` metrics. |

## Dashboard Sources

- **gnetId dashboards**: Imported from Grafana.com and customized for the homelab environment.
- **Custom dashboards**: Built from scratch for homelab-specific use cases (security, audit, Trivy).

## How They Are Loaded

The `base/kustomization.yaml` uses a `configMapGenerator` to create the `grafana-dashboards-files` ConfigMap with each JSON file mapped to a key name:

```
kubernetes-cluster.json  -> kubernetes-cluster-dashboard.json
node-metrics.json        -> node-exporter-dashboard.json
traefik-ingress.json     -> traefik-dashboard.json
trivy-vulnerabilities.json -> trivy-vulnerability-dashboard.json
security-overview.json   -> security-overview-dashboard.json
kubernetes-audit.json    -> kubernetes-audit-dashboard.json
```

This ConfigMap is mounted in the Grafana Deployment at `/var/lib/grafana/dashboards`.
