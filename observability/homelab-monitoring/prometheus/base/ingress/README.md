# prometheus/base/ingress

TLS certificate and Ingress for external access to the Prometheus web UI.

## Files

| File | Description |
|------|-------------|
| `certificate.yaml` | cert-manager Certificate (`prometheus-tls-cert`) for `metrics.example.com`, issued by the `homelab-ca` ClusterIssuer. Creates a TLS secret named `prometheus-tls-cert`. |
| `ingress.yaml` | Kubernetes Ingress routing `metrics.example.com` to the Prometheus service on port 9090. Uses the `traefik` IngressClass with TLS termination. Includes a commented-out Authentik forward auth middleware annotation for optional SSO protection. |

## Access

- **URL**: `https://metrics.example.com`
- **Entrypoint**: Traefik `websecure` (HTTPS)
- **Authentication**: None by default (Authentik middleware can be uncommented)
