# Monitoring Stack

Complete observability stack providing metrics collection, visualization, alerting, and service availability probing. The core stack is deployed via the kube-prometheus-stack Helm chart, supplemented by custom exporters, dashboards, alert rules, and ServiceMonitors.

Deployed by the `monitoring` Flux Kustomization from `clusters/homelab/apps.yaml`, which depends on `infrastructure-configs` and uses SOPS decryption.

## Directory Structure

```
monitoring/
  kustomization.yaml              # Top-level aggregation of all monitoring resources
  monitoring-release.yaml         # kube-prometheus-stack HelmRelease (Prometheus, Grafana, AlertManager, node-exporter)
  autoscaling/
    vpa.yaml                      # VPA in Auto mode for all monitoring workloads
  blackbox-exporter/
    helmrelease.yaml              # Blackbox exporter for HTTP/TCP probes
    probes.yaml                   # Probe targets (all services with SLOs)
  grafana/
    base/                         # Custom Grafana deployment overlay (config, dashboards, ingress, secrets, storage)
    dashboards/                   # Custom Grafana dashboard ConfigMaps (JSON)
  prometheus/
    base/
      config/                     # Prometheus scrape configuration
      deployment/                 # Prometheus Deployment override
      ingress/                    # Prometheus IngressRoute
      rbac/                       # Prometheus ClusterRole/ServiceAccount
      rules/                      # PrometheusRule resources (alerts, recording rules, SLOs)
      service/                    # Prometheus Service
      servicemonitors/            # Core Kubernetes ServiceMonitor
      storage/                    # Prometheus PVC
      namespace.yaml              # Monitoring namespace
  pve-exporter/
    base/                         # Proxmox VE metrics exporter (Deployment, ServiceMonitor)
  idrac-exporter/
    base/                         # Dell iDRAC Redfish metrics exporter (Deployment, ServiceMonitor)
  servicemonitors/                # Additional ServiceMonitors for applications
```

## Core Components (kube-prometheus-stack)

The `monitoring-release.yaml` HelmRelease (chart version 79.10.0) deploys:

| Component | Purpose |
|-----------|---------|
| Prometheus | Metrics collection and storage, PromQL query engine |
| Grafana | Dashboards and visualization (SSO via Authentik) |
| AlertManager | Alert routing and notification (ntfy-only, Discord removed) |
| node-exporter | Host-level metrics from all nodes |
| kube-state-metrics | Kubernetes object state metrics |

## Custom Exporters

| Exporter | Directory | Target | Metrics |
|----------|-----------|--------|---------|
| Blackbox Exporter | `blackbox-exporter/` | HTTP/TCP endpoints | Service availability, latency, TLS certificate expiry |
| PVE Exporter | `pve-exporter/` | Proxmox VE API | VM status, resource usage, storage, cluster health |
| iDRAC Exporter | `idrac-exporter/` | Dell iDRAC Redfish | Server temperatures, fans, drives, power, firmware |

## Alert Rules

Located in `prometheus/base/rules/`:

| File | Category | Examples |
|------|----------|---------|
| `infrastructure-alerts.yaml` | Infrastructure | Node down, disk pressure, NFS mount failures, certificate expiry |
| `slo-alerts.yaml` | SLO | Error budget burn rate, availability targets, latency thresholds |
| `security-alerts.yaml` | Security | Failed auth attempts, privilege escalation, suspicious processes |
| `trivy-security-alerts.yaml` | Vulnerabilities | Critical CVEs detected, image scan failures |
| `media-drop-alerts.yaml` | Application | Media drop watcher failures, processing errors |
| `mcp-server-alerts.yaml` | Application | MCP server health, API endpoint failures |
| `recording-rules.yaml` | Recording | Pre-computed aggregations for dashboard performance |

## Custom Dashboards

Located in `grafana/dashboards/`:

| Dashboard | Purpose |
|-----------|---------|
| `homelab-overview-dashboard.yaml` | High-level cluster health, resource usage, service status |
| `idrac-dashboard.yaml` | Server hardware health (temperatures, fans, power) |
| `kubernetes-audit-dashboard.yaml` | Kubernetes API audit events |
| `security-overview-dashboard.yaml` | Security posture (Falco, CrowdSec, Trivy) |
| `trivy-vulnerability-dashboard.yaml` | Container vulnerability scan results |
| `media-drop-watcher-dashboard.yaml` | Media file processing pipeline |

## Additional ServiceMonitors

Located in `servicemonitors/`:

| File | Target | Namespace |
|------|--------|-----------|
| `authentik.yaml` | Authentik SSO metrics | Authentik |
| `traefik.yaml` | Traefik ingress metrics | Traefik |
| `traefik-dmz.yaml` | Traefik DMZ metrics | Traefik-dmz |
| `postgresql.yaml` | PostgreSQL exporter metrics | (multiple) |
| `redis.yaml` | Redis exporter metrics | (multiple) |
| `media-drop-watcher.yaml` | Media watcher metrics | media |
| `flux-podmonitor.yaml` | FluxCD controller metrics | Flux-system |

## Kustomization

```yaml
resources:
  - monitoring-release.yaml
  - autoscaling
  - pve-exporter/base
  - idrac-exporter/base
  - servicemonitors
  - grafana/dashboards/*.yaml
  - prometheus/base/rules/*.yaml
  - blackbox-exporter
```
