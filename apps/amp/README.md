# AMP (Application Management Panel)

AMP is a game server management panel that runs on a dedicated VM (<internal-ip>), not inside the Kubernetes cluster. The Kubernetes manifests here provide ingress routing to the external VM through Traefik.

## Architecture

AMP runs directly on the VM at `<internal-ip>:8081`. Kubernetes acts as a reverse proxy via Traefik IngressRoute, providing TLS termination and unified access through the `amp.example.com` FQDN.

- **Namespace**: `amp`
- **FQDN**: `https://amp.example.com`
- **External VM IP**: `<internal-ip>`
- **External Port**: `8081`
- **TLS**: Wildcard certificate (`wildcard-tls`)

## Directory Structure

```
amp/
  base/
    kustomization.yaml
    namespace.yaml
    service.yaml
    ingressroute.yaml
```

## File Descriptions

### `base/kustomization.yaml`

Root Kustomization that assembles all resources in the `amp` namespace. Applies standard labels (`app.kubernetes.io/part-of: amp`, `app.kubernetes.io/managed-by: flux`).

### `base/namespace.yaml`

Creates the `amp` namespace with labels:
- `app.kubernetes.io/component: gameserver` -- categorizes the workload type
- `tls.example.com/wildcard: "true"` -- signals wildcard TLS cert distribution
- `goldilocks.fairwinds.com/enabled: "true"` -- enables Goldilocks VPA recommendations

### `base/service.yaml`

Defines two services for routing to the external AMP VM:

1. **`amp-external`** (ExternalName) -- DNS-based routing to `amp-direct.example.com`
2. **`amp`** (ClusterIP + manual Endpoints) -- IP-based routing directly to `<internal-ip>:8081`. This is the primary service used by the IngressRoute for reliable routing.

The manual Endpoints object maps the ClusterIP service to the VM's actual IP address.

### `base/ingressroute.yaml`

Traefik IngressRoute for HTTPS access:
- Matches `Host(amp.example.com)` on the `websecure` entrypoint
- Routes to the `amp` service on port 8081
- Applies the `amp-headers` middleware for security headers
- Uses the `wildcard-tls` secret for TLS

Also defines the **`amp-headers` Middleware** with:
- XSS filter and content-type sniffing protection
- `frameDeny: false` because AMP uses iframes for game server consoles
- HSTS with subdomains (1 year)

## Dependencies

- Traefik IngressRoute controller
- Wildcard TLS certificate (`wildcard-tls`) from cert-manager
- AMP VM must be running at `<internal-ip>:8081`
- DNS resolution for `amp.example.com` via AdGuard/external-DNS

## Secrets

No Kubernetes secrets are required. AMP manages its own credentials on the VM.

## Autoscaling

Not applicable -- AMP runs on an external VM, not as a Kubernetes workload.
