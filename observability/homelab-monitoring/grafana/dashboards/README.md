# grafana/dashboards

Grafana dashboards delivered as Kubernetes ConfigMap resources with the `grafana_dashboard: "1"` label. The Grafana sidecar in the kube-prometheus-stack HelmRelease auto-discovers these ConfigMaps and loads the embedded JSON dashboards.

These ConfigMaps are referenced directly from the root `kustomization.yaml`.

## Files

| File | Dashboard Title | Datasource | Description |
|------|----------------|------------|-------------|
| `mikrotik-dashboard.yaml` | MikroTik MKTXP | Prometheus | Network device monitoring for all MikroTik devices. Panels: router uptime, CPU load, memory usage, interface traffic (RX/TX in bps), DHCP lease count, top 20 firewall rules by bytes, TCP/UDP connection stats. Includes a `$router` template variable for device filtering. Source: [Grafana.com #13679](https://grafana.com/grafana/dashboards/13679-mikrotik-mktxp-exporter/). |
| `kubernetes-audit-dashboard.yaml` | Kubernetes Audit | Loki | Kubernetes operational issue detection. Stat panels for RBAC denials, CrashLoopBackOff, image pull failures, and OOM kills. Log panels showing detailed entries for each category. Default time range: 24h. |
| `security-overview-dashboard.yaml` | Security Overview | Loki | SIEM-style security log analysis. Stat panels for failed auth attempts, sudo commands, permission denials, and OOM events. Log panels for failed authentication, sudo usage, and critical security errors. Default time range: 24h. |
| `trivy-vulnerability-dashboard.yaml` | Trivy Vulnerabilities | Prometheus | Container vulnerability scanning overview. Stat panels for Critical/High/Medium vulnerability counts and total scanned images. Pie charts for severity distribution and Critical+High by namespace. Time series trend chart. Default time range: 30d. |

## ConfigMap Labels

All ConfigMaps share these labels for sidecar discovery:

```yaml
labels:
  grafana_dashboard: "1"
  app.kubernetes.io/name: grafana
```

The Grafana sidecar (configured in `monitoring-release.yaml` with `searchNamespace: ALL` and `label: grafana_dashboard`) watches for ConfigMaps with the `grafana_dashboard` label across all namespaces and loads their JSON content as dashboards.

## MikroTik Dashboard Template Variable

The MikroTik dashboard includes a `$router` template variable populated by the query `label_values(mktxp_system_uptime, routerboard_name)`. This allows filtering all panels to specific devices (RB4011, CRS317, CRS328) or viewing all devices at once.
