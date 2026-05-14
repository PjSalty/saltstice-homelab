# ADR: Flux multi-source (apps repo + secrets repo)

**Status:** Accepted

## Context

GitOps reconciliation needs apps AND secrets. The naive setup puts
both in one repo: Kustomize manifests next to SOPS-encrypted secret
manifests. Works. Has problems.

## Decision

Two GitRepository sources in Flux. Apps in one repo, SOPS-encrypted
secrets in a separate repo. Every app Kustomization
`dependsOn: [secrets]`.

## Reasoning

Different lifecycles. Manifest changes happen daily. Secret
rotations happen on a separate schedule. Putting them in the same
repo means rotation triggers app reconciliation that doesn't need to
happen.

Different access controls. Manifest repo is open to all team
members. Secrets repo is admin-only. Same access boundary in CI:
manifest CI runners don't need the SOPS Age key; the secrets
repo's CI does.

Different audit trails. `git log` on the secrets repo answers
"when did this credential last change?" cleanly without app commits
in between.

Different blast radius on force-push or rewrite. Filter-repo on the
secrets repo doesn't touch app history.

## Implementation

```yaml
# Source A, apps
apiVersion: source.toolkit.fluxcd.io/v1
kind: GitRepository
metadata:
  name: flux-system
  namespace: flux-system
spec:
  interval: 5m
  url: https://gitlab.example.com/infrastructure/homelab-kubernetes.git
  ref: { branch: main }

---
# Source B, secrets
apiVersion: source.toolkit.fluxcd.io/v1
kind: GitRepository
metadata:
  name: secrets
  namespace: flux-system
spec:
  interval: 1m
  url: https://gitlab.example.com/infrastructure/secrets.git
  ref: { branch: main }
  secretRef: { name: secrets-deploy-key }

---
# Every app Kustomization depends on the secrets one
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: secrets
  namespace: flux-system
spec:
  interval: 5m
  path: ./kubernetes
  prune: true
  sourceRef: { kind: GitRepository, name: secrets }
  decryption:
    provider: sops
    secretRef: { name: sops-age }

---
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: my-app
  namespace: flux-system
spec:
  interval: 30m
  path: ./apps/my-app
  sourceRef: { kind: GitRepository, name: flux-system }
  dependsOn:
    - { name: secrets }
```

## What i gave up

Atomic cross-repo MRs. A change that adds an app + its secret needs
two MRs in two repos. Worth the lifecycle isolation.

## When i would reconsider

Single-developer cluster with no rotation cadence, back to one
repo is fine. The two-repo split pays off when rotations happen
on a real cadence and access control matters.
