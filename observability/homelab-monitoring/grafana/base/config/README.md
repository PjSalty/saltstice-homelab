# grafana/base/config

Grafana server configuration, datasource definitions, and dashboard provider setup.

## Files

| File | Description |
|------|-------------|
| `grafana-config.yaml` | ConfigMap (`grafana-config`) containing the full `grafana.ini` configuration file. |
| `datasources.yaml` | ConfigMap (`grafana-datasources`) defining Prometheus and Loki as data sources. Labeled `grafana_datasource: "true"` for sidecar auto-discovery. |
| `dashboard-provider.yaml` | ConfigMap (`grafana-dashboard-provider`) defining three dashboard providers that load JSON files from disk. |
| `dashboards-configmap.yaml` | Empty ConfigMap (`grafana-dashboards`) with `grafana_dashboard: "true"` label. Placeholder for inline dashboard data. |
| `dashboards-files-configmap.yaml` | Empty ConfigMap (`grafana-dashboards-files`) with `grafana_dashboard: "true"` label. Populated by the `configMapGenerator` in `base/kustomization.yaml`. |

## Grafana Configuration (`grafana.ini`)

### Server

| Setting | Value |
|---------|-------|
| `protocol` | http |
| `http_port` | 3000 |
| `domain` | grafana.example.com |
| `root_url` | https://grafana.example.com |

### Authentication

- **Local login**: Enabled (not disabled)
- **OAuth auto-login**: Disabled (users see login page)
- **Anonymous access**: Disabled
- **Sign-up**: Disabled for local accounts, enabled for OAuth

### Authentik OIDC SSO

| Setting | Value |
|---------|-------|
| `client_id` | grafana-SSO |
| `client_secret` | Loaded from `/etc/secrets/oidc_secret` |
| `scopes` | openid profile email groups |
| `auth_url` | https://auth.example.com/application/o/authorize/ |
| `token_url` | https://auth.example.com/application/o/token/ |
| `api_url` | https://auth.example.com/application/o/userinfo/ |
| `role_attribute_path` | `Grafana Admins` -> Admin, `Grafana Editors` -> Editor, otherwise Viewer |
| `tls_skip_verify_insecure` | true (for internal CA) |

### Other Settings

| Setting | Value |
|---------|-------|
| Default home dashboard | `/var/lib/grafana/dashboards/kubernetes-cluster.json` |
| Log level | info (console) |
| Analytics/update checks | Disabled |

## Datasources

### Prometheus (default)

| Setting | Value |
|---------|-------|
| URL | `http://prometheus.monitoring.svc.cluster.local:9090` |
| Access | proxy |
| Scrape interval | 15s |
| HTTP method | POST |

### Loki

| Setting | Value |
|---------|-------|
| URL | `http://loki.loki.svc.cluster.local:3100` |
| Access | proxy |
| Max lines | 1000 |
| Derived fields | Links pod names to Explore queries |

## Dashboard Providers

Three providers load dashboards from disk:

| Provider | Folder | Path |
|----------|--------|------|
| `default` | (root) | `/var/lib/grafana/dashboards` |
| `kubernetes` | Kubernetes | `/var/lib/grafana/dashboards/kubernetes` |
| `infrastructure` | Infrastructure | `/var/lib/grafana/dashboards/infrastructure` |

All providers allow UI edits (`editable: true`, `allowUiUpdates: true`).
