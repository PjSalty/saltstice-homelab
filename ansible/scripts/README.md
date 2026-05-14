# scripts/

CI/CD helper scripts used by the GitLab pipeline.

## Files

| File | Purpose |
|------|---------|
| `ci-deploy-scope.sh` | Determines deploy scope (limit/tags) based on changed files |
| `ci-health-check.sh` | Post-deploy health check for infrastructure services |

## ci-deploy-scope.sh

Called by the `ansible:deploy` CI job to scope deployments to only the hosts and tags affected by the current commit. Analyzes `git diff` against the merge base and maps changed files to Ansible `--limit` and `--tags` flags.

### Output Variables

- `DEPLOY_MODE` -- `full` (base roles changed), `scoped` (specific roles changed), or `skip` (no deploy-relevant changes)
- `DEPLOY_LIMIT` -- Ansible `--limit` value (e.g., `gitlab:harbor`)
- `DEPLOY_TAGS` -- Ansible `--tags` value (e.g., `gitlab,harbor`)

### Scope Mapping

| Changed Path | Limit | Tags |
|-------------|-------|------|
| `roles/common/*`, `roles/ssh/*`, etc. | (full deploy) | (all) |
| `roles/gitlab/*` | `gitlab` | `gitlab` |
| `roles/harbor/*` | `harbor` | `harbor` |
| `roles/haproxy/*` | `load_balancers` | `load-balancers` |
| `roles/k8s-prereqs/*` | `k8s_cluster` | `kubernetes` |
| `roles/gpu/*` | `gpu_workers` | `gpu` |
| `roles/docker/*` | `infrastructure:amp_servers:vpn_servers:ci_runner` | `infrastructure,amp,vpn,ci-runner` |
| `.gitlab-ci.yml`, `*.md`, `scripts/*` | (skip) | (skip) |

### Usage

```bash
eval $(bash scripts/ci-deploy-scope.sh)
ansible-playbook ... $DEPLOY_LIMIT $DEPLOY_TAGS
```

## ci-health-check.sh

Post-deploy health verification script. Connects to key infrastructure hosts via SSH and checks service health.

### Checks Performed

- **GitLab** (<internal-ip>): API HTTP 200, Docker containers running
- **Harbor** (<internal-ip>): Health API HTTP 200, Docker containers running
- **AdGuard** (<internal-ip>): Web UI HTTP 200
- **HAProxy-1** (<internal-ip>): HAProxy + keepalived systemd active, stats endpoint
- **HAProxy-2** (<internal-ip>): HAProxy + keepalived systemd active

### Usage

```bash
./scripts/ci-health-check.sh <ssh-key-path>
```

Exits with code 1 if any checks fail.
