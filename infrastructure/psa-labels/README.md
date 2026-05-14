# Pod Security Admission Labels

Namespace-level Pod Security Admission (PSA) labels that enforce Kubernetes Pod Security Standards. Every namespace is assigned one of three levels: `privileged`, `baseline`, or `restricted`.

Deployed by the `infrastructure-psa-labels` Flux Kustomization with `force: true` to guarantee label ownership via server-side apply, even when namespace definitions in other Kustomizations set conflicting labels. Must run before `infrastructure-controllers` because some controllers (CrowdSec, Falco) require `privileged` PSA.

## Files

| File | Purpose |
|------|---------|
| `psa-labels.yaml` | Namespace definitions with PSA enforce/warn/audit labels for all namespaces |

## Security Levels

### Privileged

Unrestricted policy for system namespaces and workloads requiring host access:

- `kube-system` -- Core Kubernetes components
- `democratic-csi` -- iSCSI CSI driver needs host access for block device management
- `falco` -- Runtime security requires eBPF/syscall access
- `crowdsec` -- IPS/IDS needs network-level access
- `nvidia-device-plugin` -- GPU device plugin requires host device access

### Baseline

Minimally restrictive, prevents known privilege escalations:

- `nfs-system`, `metallb-system`, `karpenter`, `velero`
- `traefik`, `traefik-dmz` (need NET_BIND_SERVICE for ports 80/443)
- `gitlab-runner` (runner pods need container creation)
- `loki`, `monitoring`

### Restricted

Security best practices enforced (non-root, read-only rootfs, no privilege escalation):

- `authentik`, `docmost`, `headlamp`, `vaultwarden`, `semaphore`
- `cert-manager`, `external-secrets`, `external-dns`, `kyverno`
- `flux-system`, `reloader`, `goldilocks`, `vpa`
- `ntfy`, `media`, `unifi`, `automation`, `security`

## Kustomization

```yaml
resources:
  - psa-labels.yaml
```
