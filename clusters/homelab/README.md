# Homelab Cluster

FluxCD entry point for the production homelab cluster. This directory is the `path` that the root `flux-system` Kustomization watches. Everything deployed to the cluster is referenced from files in this directory.

## Files

| File | Purpose |
|------|---------|
| `kustomization.yaml` | Root Kustomize aggregation -- lists all resources Flux should apply |
| `infrastructure.yaml` | Core infrastructure Flux Kustomizations (sources, controllers, configs, RBAC, PSA, quotas, network policies) |
| `infrastructure-kustomizations.yaml` | Per-component infrastructure Kustomizations (MetalLB, cert-manager, storage, VPA, Karpenter, Loki, Tempo, etc.) |
| `apps.yaml` | Application Flux Kustomizations (Jellyfin, Authentik, Vaultwarden, monitoring, etc.) |
| `secrets-source.yaml` | GitRepository pointing to the SOPS-encrypted secrets repo (`infrastructure/secrets.git`) |
| `secrets.yaml` | Flux Kustomization that applies SOPS-decrypted secrets from the secrets repo |

### Flux-system/

| File | Purpose |
|------|---------|
| `gotk-components.yaml` | FluxCD bootstrap reference (install instructions for Flux controllers) |
| `flux-system-kustomization.yaml` | Self-referencing Kustomization that watches `clusters/homelab/` every 10 minutes |

### sources/

| File | Purpose |
|------|---------|
| `gitlab-source.yaml` | GitRepository `homelab` pointing to `infrastructure/homelab-kubernetes.git` on the internal GitLab |

### kustomizations/

Additional per-application Flux Kustomizations that are not grouped in `apps.yaml`:

| File | Application | Notes |
|------|------------|-------|
| `amp.yaml` | AMP game server | Separate due to custom dependencies |
| `cluster-cleanup.yaml` | Cluster cleanup CronJob | Infrastructure maintenance |
| `kyverno-policies.yaml` | Kyverno ClusterPolicies | Depends on Kyverno controller being ready |
| `ntfy.yaml` | ntfy push notifications | |
| `sbom-manager.yaml` | SBOM management | Security scanning |
| `seaweedfs.yaml` | SeaweedFS object storage | S3-compatible backend for GitLab Runner, Velero, AMP |
| `trivy.yaml` | Trivy vulnerability scanner | Container security scanning |

## Reconciliation Architecture

```
flux-system Kustomization (watches clusters/homelab/)
    |
    +-- kustomization.yaml (aggregates everything below)
         |
         +-- flux-system/         Bootstrap (self-referencing)
         +-- sources/             GitRepository for homelab-kubernetes
         +-- secrets-source.yaml  GitRepository for infrastructure/secrets
         |
         +-- infrastructure.yaml  Core infrastructure chain:
         |     sources -> psa-labels -> controllers -> configs -> rbac
         |     psa-labels -> resource-quotas
         |     configs -> network-policies
         |
         +-- infrastructure-kustomizations.yaml  Per-component:
         |     metallb, cert-manager, vpa, goldilocks, karpenter,
         |     democratic-csi, nfs-storage, loki, tempo, kyverno, etc.
         |
         +-- secrets.yaml         SOPS secrets (from secrets repo)
         |
         +-- apps.yaml            Applications:
         |     jellyfin, authentik, vaultwarden, monitoring, etc.
         |
         +-- kustomizations/      Additional apps:
               amp, ntfy, trivy, seaweedfs, kyverno-policies, etc.
```

## Secrets Architecture

Secrets are managed through a separate Git repository (`infrastructure/secrets`) to:
- Prevent merge conflicts during automated credential rotation
- Provide a clean audit trail for secret changes
- Enable tighter access control than the main manifest repo

The `secrets` Kustomization has no dependencies and is a foundation layer. Application Kustomizations use `dependsOn: secrets` to make sure secrets exist before pods start.

## SSOT Variable Substitution

All Flux Kustomizations use `postBuild.substituteFrom` to inject values from two ConfigMaps:

- **`image-versions`** -- Pinned versions (e.g., `${HELM_TRAEFIK}`, `${IMAGE_JELLYFIN}`)
- **`network-config`** -- Network topology (e.g., `${DOMAIN}`, `${TRAEFIK_LB_IP}`, `${NFS_SERVER}`)

This makes sure manifests never contain hardcoded versions or IPs.
