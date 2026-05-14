# Harbor

Private container registry. Runs as a VM rather than a K8s workload.
the bootstrap dependency is wrong otherwise (cluster needs the
registry to pull images, registry runs in cluster). Docker Compose on
a dedicated VM, fronted by Traefik via an external service in K8s.

## What it does

- **Project hosting** for `infrastructure/`, `homelab/`, `tools/`.
 every custom-built image goes here.
- **Proxy caches** for upstream registries (Docker Hub, GHCR, GCR,
 Quay, K8s registry) so the cluster doesn't depend on internet for
 image pulls.
- **Trivy-backed vulnerability scanning** wired into the CI promote
 gate.
- **OIDC SSO** via Authentik for human access.

## How K8s reaches it

There's no Harbor-in-K8s service; the cluster talks to
`harbor.example.com` over the LAN. Traefik in K8s routes the
external hostname via an `ExternalName` Service / Endpoints + Service
pair so that the K8s name resolution works the same way internal
cluster routes do. Auth uses pull-secrets injected by Kyverno into
every namespace that needs them (`inject-harbor-pull-secret` policy).

## Containerd registry mirror, not chart-level overrides

The pattern that works: configure containerd's `registries.yaml` on
every node so `docker.io`, `ghcr.io`, `quay.io`, `gcr.io` all silently
rewrite to the Harbor proxy paths. Per-chart `image.registry` overrides
in HelmReleases don't work, different chart authors construct image
strings differently and you end up with double-prefix paths like
`harbor.example.com/dockerhub-proxy/quay.io/...`. The full incident is
in
[`incidents/2026-04-09-helm-image-registry-override.md`](../../incidents/2026-04-09-helm-image-registry-override.md).

## Files

| File | Purpose |
|---|---|
| `external-service.yaml` | `Service` + `Endpoints` pair routing `harbor` to the VM IP |
| `traefik-route.yaml` | `IngressRoute` and `ServersTransport` for TLS-to-origin |

## Garbage collection

Harbor itself runs the GC schedule weekly. Retention policies on each
project: keep last 10 `:sha-*` tags, keep all `:vX.Y.Z` semver tags,
keep `:latest` and `:stable`.
