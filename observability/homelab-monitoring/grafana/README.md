# grafana

Grafana visualization and dashboard configuration. The primary Grafana instance is deployed via the kube-prometheus-stack HelmRelease, but this directory contains standalone deployment resources and custom dashboards delivered as ConfigMap-based Grafana dashboard resources.

## Directory Structure

```
grafana/
  base/                 Standalone Grafana deployment (Kustomize base)
    config/             Grafana configuration, datasources, dashboard providers
    dashboards/         Dashboard JSON files (6 dashboards)
    deployment/         Grafana server Deployment
    ingress/            TLS certificate and Ingress
    jobs/               Dashboard initialization Job
    secrets/            SOPS-encrypted admin credentials and OIDC secret
    service/            ClusterIP Service
    storage/            10Gi NFS PVC
  dashboards/           ConfigMap-wrapped dashboards for Grafana sidecar auto-discovery
```

## Dashboard Delivery

Dashboards are delivered two ways:

1. **`base/dashboards/`**: Raw JSON files loaded via `configMapGenerator` in `base/kustomization.yaml` and mounted as volumes in the standalone deployment.
2. **`dashboards/`**: ConfigMap resources labeled `grafana_dashboard: "1"` for auto-discovery by the Grafana sidecar in the kube-prometheus-stack HelmRelease. These are referenced directly from the root `kustomization.yaml`.

## Authentication

Grafana uses Authentik OIDC SSO:
- **Client ID**: `grafana-sso`
- **Role mapping**: `Grafana Admins` group gets Admin role, `Grafana Editors` gets Editor, everyone else gets Viewer
- **OIDC secret**: Stored in the `grafana-admin-secret` SOPS-encrypted secret
