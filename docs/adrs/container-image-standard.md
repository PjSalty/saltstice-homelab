# Container Image Build Standard

All custom container images in the homelab follow this standard.
Build → scan → promote → Renovate → Flux deploy. Same template every
time.

## Pipeline flow

```
Build (sha tag) → Scan (Trivy gate) → Promote (semver) → Renovate (MR) → Flux (deploy)
```

### Build
- Tool: DinD + BuildKit (Docker 29)
- Template: `.container:build` from `homelab-ci-templates/container-build.yml`
- Tag: `sha-<commit-short>`, immutable, unique per commit
- MR pipelines: build only (validates Dockerfile compiles, no push)
- Main / tag / schedule: build + push to Harbor

### Scan
- Tool: Trivy
- Gate: CRITICAL or HIGH vulnerabilities block promotion
- Template: `.container:scan`
- Runs after build, only when image was pushed

### Promote
- Template: `.container:promote`
- Main push: `sha-abc1234` → `:latest`
- Git tag (`v1.2.3`): `sha-abc1234` → `:v1.2.3` + `:latest`
- Weekly schedule: `sha-abc1234` → `:latest` (picks up base image patches)

### Renovate
- Watches Harbor for new semver tags on every project
- Custom manager opens MR to bump `image-versions.yaml` in `homelab-kubernetes`
- Auto-merges patch / minor; major requires manual review

### Flux
- Reconciles the SSOT `image-versions.yaml` from Git
- `postBuild.substituteFrom` injects the new image into every
 HelmRelease that references it
- Rolling restart of affected Deployments / StatefulSets

## Triggers

| Event | Build | Scan | Promote | Tags |
|---|---|---|---|---|
| MR | yes (no push) | no | no | none |
| Main push | yes | yes | yes | `sha-<short>`, `latest` |
| Git tag (`v1.2.3`) | yes | yes | yes | `sha-<short>`, `v1.2.3`, `latest` |
| Weekly schedule | yes | yes | yes | `sha-<short>`, `latest` |
| Manual (web) | yes | yes | yes | `sha-<short>`, `latest` |

## Tagging

| Tag | Mutability | Purpose |
|---|---|---|
| `sha-<short>` | immutable | every build, audit trail |
| `vX.Y.Z` | immutable | release tag, Renovate tracks these |
| `:latest` | mutable | last green main build |
| `:stable` | mutable | CI tooling images only (not K8s workloads) |

Production K8s workloads MUST pin to semver tags. Renovate handles bumps.
CI tooling images may use `:stable` since they're not K8s workloads.

## Image registry

All images go through Harbor proxy caches. No direct internet pulls.

| Upstream | Harbor proxy path | Project |
|---|---|---|
| Docker Hub | `harbor.example.com/dockerhub-proxy/` | dockerhub-proxy |
| GHCR | `harbor.example.com/ghcr-proxy/` | ghcr-proxy |
| GCR | `harbor.example.com/gcr-proxy/` | gcr-proxy |
| Custom (infra) | `harbor.example.com/infrastructure/` | infrastructure |
| Custom (apps) | `harbor.example.com/homelab/` | homelab |
| CI tooling | `harbor.example.com/tools/` | tools |

Dockerfiles MUST reference Harbor proxy paths, not upstream registries:

```dockerfile
# Correct
ARG HARBOR_REGISTRY=harbor.example.com
FROM ${HARBOR_REGISTRY}/dockerhub-proxy/library/golang:1.26-bookworm AS builder
FROM ${HARBOR_REGISTRY}/gcr-proxy/distroless/static-debian12:nonroot

# Wrong
FROM golang:1.26-bookworm
FROM gcr.io/distroless/static-debian12:nonroot
```

## CI usage

```yaml
include:
  - project: 'infrastructure/homelab-ci-templates'
    file: '/container-build.yml'

variables:
  HARBOR_REGISTRY: harbor.example.com

build-docker:
  extends: .container:build
  variables:
    CONTAINER_IMAGE: ${HARBOR_REGISTRY}/infrastructure/my-app
    CONTAINER_CONTEXT: .
    CONTAINER_FILE: Dockerfile
  rules:
    - if: $CI_PIPELINE_SOURCE == "merge_request_event"
      changes: [Dockerfile, "**/*.go", go.mod, go.sum]
    - if: $CI_COMMIT_BRANCH == $CI_DEFAULT_BRANCH
    - if: $CI_COMMIT_TAG
    - if: $CI_PIPELINE_SOURCE == "schedule"

scan-docker:
  extends: .container:scan
  needs: [build-docker]
  variables:
    CONTAINER_IMAGE: ${HARBOR_REGISTRY}/infrastructure/my-app
  rules:
    - if: $CI_COMMIT_BRANCH == $CI_DEFAULT_BRANCH
    - if: $CI_COMMIT_TAG
    - if: $CI_PIPELINE_SOURCE == "schedule"

promote-docker:
  extends: .container:promote
  needs: [scan-docker]
  variables:
    CONTAINER_IMAGE: ${HARBOR_REGISTRY}/infrastructure/my-app
    CONTAINER_PROMOTE_TAGS: "${CI_COMMIT_TAG:+${CI_COMMIT_TAG} }latest"
  rules:
    - if: $CI_COMMIT_BRANCH == $CI_DEFAULT_BRANCH
    - if: $CI_COMMIT_TAG
    - if: $CI_PIPELINE_SOURCE == "schedule"
```

Required CI/CD variables (protected): `HARBOR_USERNAME`, `HARBOR_PASSWORD`.

## SSOT integration

Custom images are referenced via `infrastructure/configs/ssot/image-versions.yaml`:

```yaml
data:
  IMAGE_HOMELAB_CLI: harbor.example.com/infrastructure/homelab-cli:v1.0.5
  IMAGE_MEDIA_DROP_WATCHER: harbor.example.com/homelab/media-drop-watcher:stable
```

Renovate custom manager in `renovate.json` tracks the Harbor projects:

```json
{
  "customType": "regex",
  "description": "Harbor infrastructure images",
  "matchStrings": [
    "IMAGE_[A-Z_]+:\\s+harbor\\.example\\.com/infrastructure/(?<depName>[^:]+):(?<currentValue>[^\\s]+)"
  ],
  "datasourceTemplate": "docker",
  "registryUrlTemplate": "https://harbor.example.com/infrastructure"
}
```

## Adding a new custom image

1. Dockerfile in the repo (Harbor proxy paths for every base image).
2. Build / scan / promote jobs via the reusable templates.
3. Set `HARBOR_USERNAME` / `HARBOR_PASSWORD` if not already set.
4. Add the image reference to `image-versions.yaml`.
5. Add a Renovate custom manager + `registryAliases` entry if the
 Harbor project isn't already tracked.

## Anti-patterns

| Anti-pattern | Why it's bad | Do this instead |
|---|---|---|
| Manual `docker build && docker push` | No audit trail, no scan gate, not reproducible | Use the CI pipeline |
| `:latest` in K8s workloads | Non-deterministic, breaks rollback | Pin semver tags |
| Direct registry pulls | Bypasses cache, rate limits, vuln scanning | Use Harbor proxy paths |
| Kaniko for CI | Requires GCR proxy, no BuildKit features, poor caching | DinD + BuildKit |
| Tag-only CI builds | Main breaks unnoticed until tag time | Build on every main push |
| Missing Trivy scan gate | CVEs reach production | Always scan before promote |
| No weekly rebuild | Stale base images, unpatched CVEs | Weekly schedule rebuild |
