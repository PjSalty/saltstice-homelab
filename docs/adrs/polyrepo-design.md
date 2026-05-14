# Polyrepo Architecture Design

## Overview

Polyrepo layout for the homelab infrastructure. Each repo has a single
purpose, single CI pipeline, and explicit dependencies on the others.

## Why polyrepo

Original layout was a monorepo with `terraform/`, `ansible/`,
`kubernetes/`, `docs/`, `secrets/`, `scripts/` all in one tree. It
worked, but every change ran every CI pipeline, branch protection
got noisy, and Flux-managed manifests got tangled with Ansible
playbooks at MR-review time. Splitting them out lets each repo own
its own cadence, lifecycle, and access control.

## Repos

### `infrastructure/homelab-terraform`
Proxmox VM provisioning. Reusable modules (`vm-bpg`, `vm-gpu-bpg`),
per-environment compositions, NetBox data sources.
CI: `validate` (fmt + validate), `plan` (auto on MR), `apply` (auto on
main, no manual gate, MR review IS the approval).
Dependencies: none. Foundation layer.

### `infrastructure/homelab-ansible`
Configuration management for the VMs Terraform created.
CI: `lint`, `syntax-check`, `check` (dry run), `deploy`.
Dependencies: `homelab-terraform` (VMs must exist).

### `infrastructure/homelab-kubernetes`
K8s manifests + FluxCD bootstrap.
- `flux-system/`, Flux bootstrap
- `infrastructure/`, cluster-wide resources (CNI, ingress, cert-manager, etc.)
- `apps/`, application deployments
- `monitoring/`, Prometheus, Grafana, Loki
CI: `validate` (kustomize build, kubeval), `reconcile` (push triggers
Flux reconcile).
Dependencies: `homelab-terraform`, `homelab-ansible`, `secrets`.

### `infrastructure/secrets`
SOPS-encrypted Kubernetes secrets. Separate repo because rotation
shouldn't trigger every other repo's CI, and access control is tighter.
Layout mirrors `apps/` and `infrastructure/` from the Kubernetes repo.
Access: automation + admins only.

### `infrastructure/homelab-docs`
Runbooks, learning material, ADRs, service docs, encyclopedia.
CI: `mkdocs build`, deploy to internal Pages.

### `infrastructure/homelab-scripts`
Ad-hoc scripts. Bootstrap, backup helpers, validation. Most have been
folded into `homelab-cli` already; this repo is the scratch pad for
one-offs that don't justify a Go subcommand.

### `infrastructure/homelab-ci-templates`
Reusable GitLab CI templates. Every other repo `include:`s from here.
- `terraform.yml`
- `ansible.yml`
- `kubernetes.yml`
- `container-build.yml` (build → scan → promote)
- `security.yml` (Trivy + gitleaks + bandit + gosec + tfsec + kubesec + SBOM)
- `lint.yml`, `notify.yml`, `orchestrate.yml`
Dependencies: none. Consumed by everything else.

### `infrastructure/homelab-agents`
Claude Code agent definitions and pre/post-tool hooks. Decoupled from
homelab-cli so prompt changes don't trigger Go rebuilds.

### `infrastructure/homelab-monitoring`
Grafana dashboards, Prometheus rules, exporter configs (mktxp for
MikroTik, alertmanager-discord, etc.). Subset of the Kubernetes
manifests but kept separate because dashboards iterate on a different
cadence.

### `infrastructure/homelab-cli`
Go binary that replaces ~25k LOC of bash. Subcommands for credential
rotation, drift detection, K8s health, MCP server, media organization,
referenced by other repos.

## Dependency graph

```
                    homelab-ci-templates
                           |
                           v
                    homelab-terraform
                           |
                           v
                    homelab-ansible
                          /  \
                         /    \
                        v      v
                  secrets    homelab-kubernetes
                        \      /
                         \    /
                          v  v
                   homelab-monitoring
```

## Access control

| Repo | Read | Write |
|---|---|---|
| `secrets` | admins only | admins only |
| `homelab-terraform` | infrastructure team | MR + review |
| Everything else | all members | MR + review |

## What this gave up

- **Atomic cross-component MRs.** A change that touches Terraform AND
 Kubernetes needs two MRs. Worth it for the lifecycle isolation.
- **Single clone for local dev.** The fix is `~/GIT/` with all 9 repos
 side by side; aliases make it feel like a workspace.
