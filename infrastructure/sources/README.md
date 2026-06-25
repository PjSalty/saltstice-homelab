# Helm Repository Sources

All HelmRepository definitions used by infrastructure controllers and application HelmReleases. These must be deployed first in the Flux dependency chain so that HelmRelease resources can resolve their chart references.

Deployed by the `infrastructure-sources` Flux Kustomization (no dependencies -- runs first).

## Repositories

| File | Repository Name | URL | Used By |
|------|----------------|-----|---------|
| `helm-repos.yaml` | `traefik` | `https://traefik.github.io/charts` | Traefik, Traefik DMZ |
| | `metallb` | `https://metallb.github.io/metallb` | MetalLB |
| | `jetstack` | `https://charts.jetstack.io` | cert-manager, trust-manager |
| | `nvdp` | `https://nvidia.github.io/k8s-device-plugin` | NVIDIA device plugin |
| | `kyverno` | `https://kyverno.github.io/kyverno/` | Kyverno policy engine |
| | `grafana` | `https://grafana.github.io/helm-charts` | Loki, Alloy |
| | `prometheus-community` | `https://prometheus-community.github.io/helm-charts` | kube-prometheus-stack |
| | `fairwinds-stable` | `https://charts.fairwinds.com/stable` | VPA, Goldilocks |
| | `vmware-tanzu` | `https://vmware-tanzu.github.io/helm-charts` | Velero |
| | `crowdsec` | `https://crowdsecurity.github.io/helm-charts` | CrowdSec |
| | `falcosecurity` | `https://falcosecurity.github.io/charts` | Falco |
| | `stakater` | `https://stakater.github.io/stakater-charts` | Reloader |
| | `external-secrets` | `https://charts.external-secrets.io` | External Secrets Operator |
| | `karpenter-proxmox` | `oci://ghcr.io/sergelogvinov/charts` (OCI) | Karpenter Proxmox provider |

All repositories use a 1-hour polling interval.

## Notes

- The Bitnami Helm Repository has been removed due to Broadcom acquisition making public repos unmaintained. External-DNS now uses `registry.k8s.io` images directly.
- The `karpenter-proxmox` repository uses OCI format (`type: oci`) rather than traditional HTTP.
- The truenas-csi HelmRepository is defined within `infrastructure/truenas-csi/base/helmrepository.yaml` rather than here, as it is deployed by a separate Flux Kustomization.

## Kustomization

```yaml
resources:
  - helm-repos.yaml
```
