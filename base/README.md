# Base Resources

Shared base resources, templates, and patches used across multiple applications. These provide reusable building blocks for namespace definitions, RBAC, and security context defaults.

## Directory Structure

### namespaces/

Namespace definitions for applications. Each file creates a Namespace resource with appropriate labels.

| File | Namespace | Notes |
|------|-----------|-------|
| `_template-namespace.yaml` | (template) | Reference template for creating new namespaces |
| `authentik-namespace.yaml` | Authentik | SSO provider |
| `dns-namespace.yaml` | DNS | DNS services |
| `external-dns-namespace.yaml` | external-DNS | AdGuard DNS management |
| `gitlab-runner-namespace.yaml` | GitLab-runner | CI/CD runner |
| `headlamp-namespace.yaml` | Headlamp | Kubernetes dashboard |
| `homarr-namespace.yaml` | Homarr | Dashboard (unused) |
| `semaphore-namespace.yaml` | Semaphore | Ansible UI |
| `vaultwarden-namespace.yaml` | Vaultwarden | Password manager |

Note: Most namespaces are now defined directly within their respective controller or application directories rather than here. PSA labels for all namespaces are centrally managed in `infrastructure/psa-labels/`.

### patches/

Reusable Kustomize patches for common configurations.

| File | Purpose |
|------|---------|
| `security-context-patch.yaml` | Standard security context for Deployments: `seccompProfile: RuntimeDefault`, `runAsNonRoot: true`, `fsGroup: 1000`. Applied via Kustomize `patches` targeting Deployments. |

### RBAC/

Cluster-wide RBAC definitions for shared services.

| File | Purpose |
|------|---------|
| `external-dns-clusterrole.yaml` | ClusterRole for external-DNS to manage DNS records |
| `external-dns-clusterrolebinding.yaml` | Binds external-DNS ServiceAccount to the ClusterRole |
| `external-dns-serviceaccount.yaml` | ServiceAccount for external-DNS |
| `gitlab-runner-rbac.yaml` | RBAC for GitLab Runner to create/manage CI/CD pods |
| `dns-rbac.yaml` | DNS service RBAC (empty placeholder) |
| `dns-serviceaccount.yaml` | DNS ServiceAccount (empty placeholder) |

Note: Headlamp RBAC has been moved to `apps/headlamp/base/rbac/` and uses a read-only ClusterRole instead of the legacy cluster-admin binding.
