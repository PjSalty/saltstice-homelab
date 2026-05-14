# grafana/base/ingress

TLS certificate and Ingress for external access to the Grafana web UI.

## Files

| File | Description |
|------|-------------|
| `certificate.yaml` | cert-manager Certificate (`grafana-tls-cert`) for `grafana.example.com`, issued by the `homelab-ca` ClusterIssuer. Creates a TLS secret named `grafana-tls-cert`. |
| `ingress.yaml` | Kubernetes Ingress routing `grafana.example.com` to the Grafana service on port 3000. Uses the `traefik` IngressClass with TLS termination. Includes a commented-out Authentik forward auth middleware annotation for optional SSO protection at the ingress level (Grafana has its own built-in Authentik OIDC integration). |

## Access

| Property | Value |
|----------|-------|
| URL | `https://grafana.example.com` |
| Entrypoint | Traefik `websecure` (HTTPS) |
| TLS Issuer | `homelab-ca` ClusterIssuer |
| Authentication | Grafana-native Authentik OIDC (not ingress-level) |
