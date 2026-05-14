# Infrastructure Controllers

HelmRelease and Deployment definitions for cluster-wide infrastructure controllers. These are the workloads that provide core platform capabilities (ingress, certificates, load balancing, security, backups, etc.) to application workloads.

Deployed by the `infrastructure-controllers` Flux Kustomization, which depends on `infrastructure-sources` (HelmRepositories) and `infrastructure-psa-labels` (Pod Security Admission).

## Controllers

| Directory | Controller | Chart | Purpose |
|-----------|-----------|-------|---------|
| `metallb/` | MetalLB | `metallb/metallb` | Bare-metal LoadBalancer implementation via BGP peering with MikroTik router |
| `traefik/` | Traefik | `traefik/traefik` | Primary ingress controller for internal services (`*.example.com`) |
| `traefik-dmz/` | Traefik DMZ | `traefik/traefik` | Isolated ingress for DMZ/community services (VLAN 60) |
| `cert-manager/` | cert-manager | `jetstack/cert-manager` | X.509 certificate lifecycle (Let's Encrypt via DNS-01 acme-DNS) |
| `trust-manager/` | trust-manager | `jetstack/trust-manager` | CA bundle distribution across namespaces |
| `external-secrets/` | External Secrets Operator | `external-secrets/external-secrets` | Syncs credentials from SOPS-decrypted source Secrets to per-namespace targets |
| `velero/` | Velero | `vmware-tanzu/velero` | Kubernetes backup and restore (S3 backend: SeaweedFS) |
| `vpa/` | Vertical Pod Autoscaler | `fairwinds-stable/vpa` | Automatic CPU/memory right-sizing for all workloads |
| `goldilocks/` | Goldilocks | `fairwinds-stable/goldilocks` | VPA recommendation dashboard (depends on VPA) |
| `kyverno/` | Kyverno | `kyverno/kyverno` | Policy engine for admission control and resource mutation |
| `crowdsec/` | CrowdSec | `crowdsec/crowdsec` | Collaborative IPS/IDS with community threat intelligence |
| `falco/` | Falco | `falcosecurity/falco` | Runtime security monitoring and syscall analysis |
| `reloader/` | Reloader | `stakater/reloader` | Auto-restarts pods on ConfigMap/Secret changes |
| `cloudflared/` | Cloudflare Tunnel | (raw Deployment) | Cloudflare tunnel connector for external access |
| `nvidia-device-plugin/` | NVIDIA Device Plugin | `nvdp/nvidia-device-plugin` | GPU scheduling support (RTX A2000) + DCGM metrics exporter |
| `cluster-cleanup/` | Cluster Cleanup | (CronJob) | Automated cleanup of orphaned resources |

## Standard Directory Structure

Each controller follows a consistent layout:

```
controller-name/
  kustomization.yaml       # Lists all resources
  helmrelease.yaml         # HelmRelease (or deployment.yaml for raw workloads)
  namespace.yaml           # Namespace definition with PSA labels
  values.yaml              # Optional: Helm values (referenced via valuesFrom)
  autoscaling/             # VPA (and optionally HPA) definitions
    kustomization.yaml
    vpa.yaml
    hpa.yaml               # Only for scalable stateless workloads
```

## Autoscaling

Every controller has a VPA in Auto mode. Stateless controllers that handle variable traffic (Traefik, Traefik DMZ, Cloudflared) also have an HPA. When both exist, the VPA uses `controlledResources: ["memory"]` to avoid conflicting with HPA on CPU scaling.

## Health Checks

The `infrastructure-controllers` Flux Kustomization defines explicit health checks for critical controllers that must be healthy before `infrastructure-configs` proceeds:

- `metallb-controller` (MetalLB-system)
- `cert-manager` (cert-manager)
- `traefik` (Traefik)
- `trust-manager` (cert-manager)
- `external-secrets` (external-secrets)

Other controllers (CrowdSec, Falco, Kyverno) are not health-checked at the Flux level to prevent slow stabilization from blocking the dependency chain.

## Kustomization

```yaml
resources:
  - metallb
  - traefik
  - traefik-dmz
  - cert-manager
  - nvidia-device-plugin
  - vpa
  - goldilocks
  - trust-manager
  - velero
  - cloudflared
  - crowdsec
  - falco
  - reloader
  - external-secrets
```
