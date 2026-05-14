# homelab-monitoring

Monitoring stack for the Salty Homelab. Deployed to the `monitoring` namespace via FluxCD.

## Components

| Component | Purpose | Access |
|-----------|---------|--------|
| **Prometheus** | Metrics collection and alerting | `prometheus.example.com` |
| **Grafana** | Visualization and dashboards | `grafana.example.com` |
| **AlertManager** | Alert routing and notifications | Internal (ntfy integration) |
| **MKTXP** | MikroTik metrics exporter | Internal (Prometheus scrapes) |
| **kube-prometheus-stack** | Helm-managed Prometheus + node-exporter + kube-state-metrics | HelmRelease |

## Architecture

```
MikroTik Devices ──→ MKTXP ──→ Prometheus ──→ AlertManager ──→ ntfy
  (RB4011, CRS317,                  │                            (homelab-saltstice-critical)
   CRS328)                          │
                                    ↓
K8s Nodes ──→ node-exporter ──→ Grafana
K8s API   ──→ kube-state-metrics    │
Traefik   ──→ ServiceMonitor        │
Authentik ──→ ServiceMonitor        ↓
                              6 Dashboards
```

## Alert Rules

| File | Alerts |
|------|--------|
| `infrastructure-alerts.yaml` | Node down, disk full, high CPU/memory, NFS mount failures |
| `slo-alerts.yaml` | Service availability SLOs, latency targets, error budgets |
| `trivy-security-alerts.yaml` | Critical/high CVEs detected in container images |

## Dashboards

| Dashboard | Purpose |
|-----------|---------|
| Kubernetes Cluster | Node resources, pod counts, namespace usage |
| Kubernetes Audit | API server audit events, RBAC denials |
| Node Exporter | Per-node CPU, memory, disk, network |
| Security Overview | RBAC status, NetworkPolicy coverage, pod security |
| Traefik | Request rates, response codes, latency by router |
| Trivy Vulnerability | CVE counts by severity, image scan results |

## MKTXP (MikroTik Exporter)

Exports metrics from 3 MikroTik devices:

| Device | IP | Role |
|--------|-----|------|
| RB4011 | <mgmt-ip> | Core router |
| CRS317 | <mgmt-ip> | 10G aggregation switch |
| CRS328 | <mgmt-ip> | PoE access switch |

Metrics: interface bandwidth, firewall counters, DHCP leases, system resources, connection tracking.

## Notifications

AlertManager routes to **ntfy only** (Discord removed):
- Topic: `homelab-saltstice-critical` on ntfy.sh
- Priorities: critical=urgent, warning=high, info=low

## Authentication

Grafana uses Authentik OIDC SSO:
- Provider: `grafana` in Authentik
- Role mapping: `Grafana Admins` group → admin role
- Auto-login enabled (skip Grafana login page)

## Structure

```
homelab-monitoring/
├── monitoring-release.yaml    kube-prometheus-stack HelmRelease
├── alertmanager-secret.yaml   SOPS-encrypted webhook credentials
├── certificates.yaml          TLS cert for monitoring ingress
├── kustomization.yaml         Root kustomization
├── prometheus/
│   └── base/
│       ├── config/            Scrape configs
│       ├── rules/             Alert rules (3 files)
│       ├── servicemonitors/   Traefik + K8s auto-discovery
│       ├── deployment/        Prometheus server
│       ├── rbac/              ServiceAccount + ClusterRole
│       ├── storage/           NFS PVC (50Gi)
│       └── ingress/           Traefik IngressRoute
├── grafana/
│   └── base/
│       ├── config/            OIDC SSO + datasources
│       ├── dashboards/        6 JSON dashboards
│       ├── deployment/        Grafana server
│       ├── sidecar/           Dashboard auto-discovery
│       ├── secrets/           SOPS-encrypted admin creds
│       ├── storage/           NFS PVC (10Gi)
│       ├── jobs/              Dashboard init job
│       └── ingress/           Traefik IngressRoute
├── mktxp/
│   └── base/
│       ├── deployment.yaml    MikroTik exporter + config
│       ├── secret.yaml        SOPS-encrypted password
│       └── servicemonitor.yaml Prometheus auto-discovery
├── alertmanager-discord/      DEPRECATED, Discord adapters (no longer deployed)
└── servicemonitors/           Additional ServiceMonitors (Authentik)
```

## CI/CD

Pipeline validates:
- Prometheus alert rules (promtool check rules)
- Grafana dashboard JSON syntax
- YAML lint (all configs)
- Gitleaks secret scanning
