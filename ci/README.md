# ci

Self-hosted GitLab. Reusable templates included by every repo. No
manual approval gates anywhere, MR review IS the gate.

## Templates

| File | Stages | Use |
|---|---|---|
| `terraform.yml` | validate, plan, apply | `terraform fmt`, validate, plan on MR, apply on main |
| `ansible.yml` | lint, syntax, check, deploy | `ansible-lint`, `--syntax-check`, `--check`, deploy via Semaphore on main |
| `kubernetes.yml` | plan, deploy, verify | `kustomize build`, `kubectl diff`, smart Flux reconcile based on changed kustomizations |
| `container-build.yml` | build, scan, promote | DinD + BuildKit, SHA tag, Trivy gate, promote to `:latest` on main |
| `security.yml` | test | Trivy + gitleaks + bandit + gosec + tfsec + kubesec + SBOM |
| `lint.yml` | validate | yamllint, shellcheck, python lint, markdownlint |
| `notify.yml` | notify | Slack / ntfy webhook templates |
| `orchestrate.yml` | trigger | cross-repo pipeline triggers via `trigger:strategy:depend` |
| `renovate.yml` | Renovate | self-hosted Renovate runner |
| `sync-config.yml` | sync | config sync helpers |
| `docker.yml` | build, test, deploy | legacy Docker pipeline (kept for backward compat) |

## Patterns

- **SHA-tag immutability**: every container build tags
 `sha-${SHORT_SHA}`. `:latest` is mutable, only on green main.
 Promotion serialized via `resource_group: container-promote`.
- **Smart Flux reconcile**: `kubernetes.yml` reads `git diff`, figures
 out which kustomizations are affected, only reconciles those. Avoids
 full-cluster reconciles on small changes.
- **Resource groups**: serialize Flux reconciles, Terraform applies,
 container promotes. Prevents pipeline races on shared state.
- **Caching**: Trivy CVE DB (~100 MB), pip packages, Terraform plugins,
 Go module cache, all keyed on lockfiles.
- **Retry**: network-sensitive jobs (Trivy, Terraform) auto-retry on
 `runner_system_failure` / `stuck_or_timeout_failure`.
- **Cross-repo orchestration**: `orchestrate.yml` chains pipelines
 via `trigger:strategy:depend` so a Terraform apply followed by an
 Ansible deploy is one MR.

## Why no manual approval gates

The MR review is the approval. A second click-to-deploy gate is
redundant, slows shipping, fragments the audit trail, and the
operator clicking it usually isn't the one who reviewed the diff. If
something needs an approval, the PR is the place. If it shouldn't
auto-deploy, gate on a `rules:if` condition (branch, tag, schedule)
not a button.

## Renovate

Custom regex managers track:

- SSOT image-versions ConfigMap (single edit point for ~50 image
 versions across the cluster)
- Harbor proxy paths (separate manager per registry: dockerhub,
 ghcr, quay, gcr, K8s)
- Helm chart versions in HelmRelease specs
- Terraform provider versions

Auto-merge for patch / minor in low-risk groups. Major requires
manual review. Grouped MRs by domain (monitoring, Traefik, security)
to avoid 30 individual MRs per Renovate run.

## Required CI/CD variables (protected)

| Variable | Purpose |
|---|---|
| `HARBOR_USERNAME`, `HARBOR_PASSWORD` | container push |
| `TF_HTTP_USERNAME`, `TF_HTTP_PASSWORD`, `TF_HTTP_ADDRESS`, `TF_HTTP_LOCK_ADDRESS` | GitLab-managed Terraform state |
| `SOPS_AGE_KEY` | decrypt SOPS secrets at runtime |
| `RENOVATE_TOKEN` | Renovate self-hosted runner |
