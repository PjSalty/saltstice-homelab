# GitLab Runner

GitLab Runner provides CI/CD execution capabilities for all GitLab pipelines. It uses the Kubernetes executor to dynamically create pods for each CI job.

## Architecture

The runner operates as a single Deployment that coordinates CI job execution:
- Registers with GitLab using the token-based authentication method (GitLab 16+)
- Spawns ephemeral pods in the `gitlab-runner` namespace for each CI job
- Uses SeaweedFS S3 for distributed build cache
- Supports Docker-in-Docker (DinD) builds with privileged mode
- Includes automation SSH key for Ansible deployment jobs

- **Namespace**: `gitlab-runner`
- **Pod Security**: `privileged` (required for DinD builds)
- **GitLab URL**: `https://gitlab.example.com`

## Directory Structure

```
gitlab-runner/
  kustomization.yaml
  base/
    kustomization.yaml
    namespace.yaml
    autoscaling/
      kustomization.yaml
      vpa.yaml
    config/
      configmap.yaml
    deployments/
      deployment.yaml
    jobs/
      runner-auto-register.yaml
    monitoring/
      service.yaml
      servicemonitor.yaml
    rbac/
      rbac.yaml
    secrets/
      automation-ssh-key.yaml
      runner-token-template.yaml
      secret-template.yaml
    storage/
      pvc.yaml
```

## File Descriptions

### `kustomization.yaml`

Top-level Kustomization referencing `base/`.

### `base/kustomization.yaml`

Assembles all base resources: namespace, RBAC, config, secrets, storage, deployment, auto-register job, monitoring, and autoscaling.

### `base/namespace.yaml`

Creates the `gitlab-runner` namespace with `privileged` Pod Security Standards (enforce, warn, audit). This is required because CI job pods need DinD (Docker-in-Docker) with privileged access for container image builds.

### `base/deployments/deployment.yaml`

GitLab Runner Deployment:
- Single replica
- Generates `config.toml` at startup from runner token
- Key runner configuration:
 - **Concurrency**: 10 simultaneous jobs
 - **Executor**: Kubernetes
 - **Privileged**: true (for DinD builds)
 - **Image pull secrets**: `harbor-pull-secret` for private Harbor registry
 - **Cache**: S3 via SeaweedFS (`seaweedfs-s3.storage.svc:8333`)
 - **Job resource limits**: 2 CPU / 4Gi memory (overridable to 4 CPU / 8Gi)
 - **Helper resources**: 500m CPU / 512Mi memory
 - **Node affinity**: Prefers worker nodes
 - **Volumes**: EmptyDir for `/builds` and `/home/gitlab-runner`, automation SSH key mounted at `/secrets/ssh`
- Prometheus metrics endpoint on port 9252
- Environment variables:
 - `RUNNER_TOKEN`: From `gitlab-runner-token` secret
 - `DEFAULT_IMAGE`: `${IMAGE_ALPINE}`
 - `S3_ACCESS_KEY`, `S3_SECRET_KEY`: From `seaweedfs-s3-credentials` secret

### `base/config/configmap.yaml`

Fallback runner configuration (`config.toml`):
- Max concurrent jobs: 10
- Check interval: 3 seconds
- JSON log format
- Prometheus metrics on port 9252

### `base/rbac/rbac.yaml`

RBAC for the Kubernetes executor:
- **ServiceAccount**: `gitlab-runner`
- **Role**: Namespace-scoped permissions for:
 - Creating/managing CI job pods, services, PVCs, ConfigMaps, secrets
 - Patching secrets (for auto-registration)
 - Getting/patching deployments (for restart after registration)
- **RoleBinding**: Binds Role to ServiceAccount

### `base/jobs/runner-auto-register.yaml`

Job that registers the runner with GitLab via API:
- Uses GitLab 16+ runner token authentication (not deprecated registration tokens)
- Creates a runner via GitLab API
- Stores the authentication token in `gitlab-runner-token` secret
- Restarts the runner deployment after registration
- TTL: 24 hours after completion

### `base/secrets/secret-template.yaml`

SOPS-encrypted Secret containing the legacy registration token (`gitlab-runner-secret`).

### `base/secrets/runner-token-template.yaml`

Template Secret for the runner authentication token (`gitlab-runner-token`):
- Annotated with `kustomize.toolkit.fluxcd.io/prune: disabled` to prevent Flux from overwriting
- Uses `IfNotPresent` SSA to only create if missing
- Data populated by the auto-register Job

### `base/secrets/automation-ssh-key.yaml`

SOPS-encrypted Secret containing the SSH private key used by CI/CD deployment jobs (e.g., Ansible playbook execution). Mounted in CI job pods at `/secrets/ssh/id_rsa`.

### `base/storage/pvc.yaml`

5Gi NFS PVC for GitLab Runner data (`/etc/gitlab-runner` config storage).

### `base/monitoring/service.yaml`

ClusterIP Service exposing Prometheus metrics on port 9252.

### `base/monitoring/servicemonitor.yaml`

Prometheus ServiceMonitor for GitLab Runner metrics:
- Scrapes port `metrics` (9252)
- 30-second interval
- Path: `/metrics`

### `base/autoscaling/vpa.yaml`

VPA (Auto mode) for the runner Deployment:
- CPU: 50m-500m
- Memory: 128Mi-512Mi

## Secrets

| Secret Name | Keys | Purpose |
|---|---|---|
| `gitlab-runner-secret` | `registration-token` | Legacy registration token (SOPS) |
| `gitlab-runner-token` | `runner-token` | Active runner authentication token |
| `automation-ssh-key` | `ssh-private-key` | SSH key for Ansible deploy jobs (SOPS) |
| `seaweedfs-s3-credentials` | `access-key`, `secret-key` | S3 cache credentials |
| `harbor-pull-secret` | Docker config | Private registry pull credentials |

## Dependencies

- GitLab instance at `gitlab.example.com`
- SeaweedFS S3 service in `storage` namespace (for build cache)
- Harbor registry (for private image pulls)
- NFS storage (for runner config persistence)
- Prometheus + ServiceMonitor CRD (for metrics collection)
