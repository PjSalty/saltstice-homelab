# RBAC

Cluster-wide Role-Based Access Control bindings for administrative access. Deployed by the `infrastructure-rbac` Flux Kustomization (no dependencies).

## Files

| File | Resources | Purpose |
|------|-----------|---------|
| `oidc-cluster-admin.yaml` | ClusterRoleBinding `oidc-cluster-admin`, ClusterRoleBinding `oidc-group-admin` | Grants `cluster-admin` to the homelab owner via Authentik OIDC authentication |

## OIDC Authentication

Two ClusterRoleBindings provide admin access:

1. **User binding** (`oidc-cluster-admin`) -- Matches the `preferred_username` claim from the Authentik OIDC token (user: `Salty`)
2. **Group binding** (`oidc-group-admin`) -- Matches the `groups` claim for members of the `headlamp-admins` group in Authentik

These are intentional `cluster-admin` bindings for a single-owner homelab. The security note in the manifest documents that production environments should use namespace-scoped roles and JIT access elevation.

Last reviewed: 2026-01-31 (infrastructure audit).

## Kustomization

```yaml
resources:
  - oidc-cluster-admin.yaml
```
