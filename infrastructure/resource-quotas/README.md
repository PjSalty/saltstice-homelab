# Resource Quotas and Limit Ranges

Safety-net resource constraints applied to application namespaces. These are intentionally generous limits designed to prevent resource exhaustion and fork bombs, not to constrain normal operations. VPA handles actual resource right-sizing.

Deployed by the `infrastructure-resource-quotas` Flux Kustomization, which depends on `infrastructure-psa-labels`.

## Files

| File | Resources | Purpose |
|------|-----------|---------|
| `resource-quotas.yaml` | ResourceQuota per namespace | Maximum pod count, CPU, and memory limits per namespace |
| `limit-ranges.yaml` | LimitRange per namespace | Default container resource requests/limits for pods that do not specify them |

## Why LimitRanges Are Required

Without a LimitRange, Kubernetes rejects pods that do not specify resource requests/limits when a ResourceQuota is active. This commonly breaks Helm chart init containers (e.g., `download-dashboards`, `wait-for-lapi`) that omit resource specs. The LimitRange provides minimal defaults (e.g., 10m CPU, 32Mi memory request) that satisfy the ResourceQuota while VPA Auto adjusts actual resources dynamically.

## Namespace Tiers

| Tier | Namespaces | Pod Limit | CPU Limit | Memory Limit |
|------|-----------|-----------|-----------|--------------|
| Small | ntfy, Headlamp, UniFi, vpn, amp, automation | 10 | 4 cores | 4Gi |
| Medium | Vaultwarden, Semaphore, Docmost, external-DNS, GitLab-runner | 20 | 8 cores | 8Gi |
| Large | Authentik, monitoring, media | 50+ | 16+ cores | 32Gi+ |

System namespaces (`kube-system`, `flux-system`, `cilium`, etc.) are intentionally excluded to preserve operational flexibility.

## Kustomization

```yaml
resources:
  - resource-quotas.yaml
  - limit-ranges.yaml
```
