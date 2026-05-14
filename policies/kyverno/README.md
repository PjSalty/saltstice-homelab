# Kyverno Policies

ClusterPolicy and ClusterCleanupPolicy definitions enforced by the Kyverno admission controller. These policies set up security guardrails, supply chain controls, certificate distribution, and automatic garbage collection across the cluster.

Deployed by the `kyverno-policies` Flux Kustomization from `clusters/homelab/kustomizations/kyverno-policies.yaml`, which depends on the Kyverno controller being installed and healthy.

## Validation Policies (Enforce)

These policies block non-compliant resources at admission time.

| File | Policy | Mode | Effect |
|------|--------|------|--------|
| `disallow-latest-tag.yaml` | `disallow-latest-tag` | Enforce | Blocks container images using `:latest` or missing a version tag. All images must use pinned versions from the SSOT (`image-versions.yaml`). |
| `require-resource-limits.yaml` | `require-resource-limits` | Enforce | Blocks pods without CPU and memory limits defined on all containers. Prevents resource starvation and makes sure fair scheduling. |
| `restrict-externalsecret-namespaces.yaml` | `restrict-externalsecret-namespaces` | Enforce | Blocks ExternalSecret creation in unapproved namespaces. Prevents unauthorized access to the credential SSOT source Secrets. |

## Validation Policies (Audit)

These policies warn on violations but do not block resource creation.

| File | Policy | Mode | Effect |
|------|--------|------|--------|
| `require-harbor-registry.yaml` | `require-harbor-registry` | Audit | Warns when images are not pulled from the internal Harbor registry (`harbor.example.com`). Makes sure supply chain security via Harbor vulnerability scanning. |
| `require-ssot-labels-on-secrets.yaml` | `require-ssot-labels-on-secrets` | Audit | Warns when Secrets lack source-of-truth labels indicating their origin (`credentials.sops.yaml`, `ansible-vault`, or `manual`). Helps track credential lifecycle. |
| `block-critical-vulnerabilities.yaml` | `block-critical-vulnerabilities` | Audit | Warns when pods use container images that have CRITICAL findings in Trivy VulnerabilityReports. New images with no prior scan are allowed; Trivy scans post-admission and alerts fire via ntfy. |

## Generate Policies

| File | Policy | Effect |
|------|--------|--------|
| `sync-wildcard-tls.yaml` | `sync-wildcard-tls` | Replicates the wildcard TLS certificate Secret from `cert-manager` namespace to all namespaces labeled with `tls.example.com/wildcard=true`. Keeps secrets synchronized on certificate renewal. |

## Cleanup Policies

Automatic garbage collection via scheduled `ClusterCleanupPolicy` resources.

| File | Policy | Schedule | Effect |
|------|--------|----------|--------|
| `cleanup-evicted-pods.yaml` | `cleanup-evicted-pods` | Every 30 minutes | Removes Failed pods that were evicted by kubelet under resource pressure |
| `cleanup-failed-pods.yaml` | `cleanup-failed-pods` | Every 30 minutes | Removes pods in Failed state |
| `cleanup-empty-replicasets.yaml` | `cleanup-empty-replicasets` | Every 30 minutes | Removes ReplicaSets with zero replicas (leftover from Deployment rollouts) |

## Health Checks

The Flux Kustomization verifies that the core validation policies are ready:

- `disallow-latest-tag`
- `require-resource-limits`
- `require-harbor-registry`
- `require-ssot-labels-on-secrets`

## Kustomization

```yaml
resources:
  - disallow-latest-tag.yaml
  - require-resource-limits.yaml
  - require-harbor-registry.yaml
  - require-ssot-labels-on-secrets.yaml
  - restrict-externalsecret-namespaces.yaml
  - sync-wildcard-tls.yaml
  - block-critical-vulnerabilities.yaml
  - cleanup-evicted-pods.yaml
  - cleanup-failed-pods.yaml
  - cleanup-empty-replicasets.yaml
```
