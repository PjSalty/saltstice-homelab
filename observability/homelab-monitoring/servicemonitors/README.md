# servicemonitors

Additional Prometheus ServiceMonitor resources for applications outside the kube-prometheus-stack defaults. These enable the Prometheus Operator to auto-discover and scrape metrics from application services.

## Files

| File | Description |
|------|-------------|
| `kustomization.yaml` | Kustomization listing `traefik.yaml` and `authentik.yaml` in the `monitoring` namespace. |
| `traefik.yaml` | ServiceMonitor targeting the Traefik ingress controller in the `traefik` namespace. Selects services with label `app.kubernetes.io/name: traefik`, scrapes the `metrics` port at `/metrics` every 30s with a 10s timeout. Labeled `release: kube-prometheus-stack` for Prometheus Operator discovery. |
| `authentik.yaml` | ServiceMonitor targeting the Authentik SSO server in the `authentik` namespace. Selects services with label `app.kubernetes.io/name: authentik`, scrapes the `http` port at `/metrics` every 30s with a 10s timeout. Labeled `release: kube-prometheus-stack` for Prometheus Operator discovery. |

## How It Connects

The kube-prometheus-stack HelmRelease in `monitoring-release.yaml` has `serviceMonitorSelectorNilUsesHelmValues: false`, which means the Prometheus Operator discovers ServiceMonitors from all namespaces regardless of labels. These ServiceMonitors are still labeled with `release: kube-prometheus-stack` for consistency.

## Adding a New ServiceMonitor

1. Create a YAML file in this directory following the existing pattern.
2. Add the filename to `kustomization.yaml` under `resources`.
3. Make sure the `namespaceSelector`, `selector` labels, and `endpoints` port/path match the target service.
