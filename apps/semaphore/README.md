# Semaphore

Ansible automation UI for running playbooks against homelab infrastructure. Semaphore provides a web interface for executing Ansible playbooks with scheduling, history, and SSO via Authentik.

## FQDN

`https://semaphore.example.com`

## Namespace

`semaphore`

## Directory Structure

```
base/
  kustomization.yaml                         - Kustomize manifest listing all resources
  namespace.yaml                             - Namespace with Goldilocks enabled
  deployments/
    semaphore-deployment.yaml                - Semaphore app Deployment with init containers
    postgres-deployment.yaml                 - PostgreSQL 15 Deployment with metrics exporter
  services/
    services.yaml                            - ClusterIP Services for Semaphore (3000) and PostgreSQL (5432, 9187)
  ingress/
    ingress.yaml                             - Traefik Ingress with wildcard TLS
  config/
    configmap.yaml                           - Base config template (non-sensitive settings)
  storage/
    storage.yaml                             - PVs and PVCs for PostgreSQL, Ansible repo, and tmp
  secrets/
    gitlab-ssh-secret.yaml                   - SOPS-encrypted GitLab SSH key pair and known_hosts
    kubeconfig-secret.yaml                   - ServiceAccount + kubeconfig for kubectl access
    ssh-secret.yaml                          - SOPS-encrypted Ansible automation SSH key
  jobs/
    setup-gitlab-repo.yaml                   - One-time job configuring Semaphore project via REST API
    setup-tasks-schedules.yaml               - One-time job creating task templates and schedules
  backup/
    pvc.yaml                                 - 2Gi NFS PVC for PostgreSQL backups
    cronjob.yaml                             - Daily pg_dump backup (3 AM, 7-day retention)
  pdb/
    pdb.yaml                                 - PodDisruptionBudget (minAvailable: 1)
  autoscaling/
    kustomization.yaml                       - Lists VPA resources
    vpa.yaml                                 - VPAs for semaphore and postgres Deployments
```

## Key Configuration

### Semaphore Deployment

The Semaphore Deployment uses five init containers that run sequentially:

1. **wait-for-Postgres**: Waits for PostgreSQL readiness using `pg_isready`
2. **clone-Ansible-repo**: Clones `homelab-ansible` from GitLab via SSH into the Ansible-repo PVC
3. **install-tools**: Downloads kubectl, Helm, and SOPS binaries into a shared emptyDir
4. **create-admin-user**: Creates the admin user via Semaphore CLI
5. **sync-SSO-users**: Promotes SSO users (Salty) to admin in all projects via direct PostgreSQL queries

The main container generates `config.json` at startup with OIDC configuration for Authentik SSO, then runs `semaphore service`.

- **Image**: Managed via `${IMAGE_SEMAPHORE}` Flux variable
- **Security**: Runs as root (UID 0) due to go-git library limitations with NFS file ownership
- **Playbook path**: `/ansible` (cloned from GitLab)
- **KUBECONFIG**: Mounted from `semaphore-kubeconfig` secret
- **SOPS key**: Age key mounted for credential decryption

### PostgreSQL Deployment

- **Image**: `${IMAGE_POSTGRES_15}`
- **Database**: `semaphore`
- **Sidecar**: Postgres-exporter for Prometheus metrics on port 9187
- **Storage**: NFS-backed PVC (5Gi)
- **Password sync**: postStart lifecycle hook syncs password from secret

### SSO Integration

Authentik OIDC is configured via environment variables:
- **Provider URL**: `https://auth.example.com/application/o/semaphore-sso/`
- **Redirect URL**: `https://semaphore.example.com/api/auth/oidc/authentik/redirect`
- **Scopes**: openid, profile, email

## Secrets

All secrets are SOPS-encrypted and managed in the `infrastructure/secrets` repo:

| Secret Name | Contents |
|-------------|----------|
| `semaphore-secrets` | Postgres-password, admin-password, encryption-key, OIDC-client-id, OIDC-client-secret, cookie-hash, cookie-encryption, GitLab-token |
| `gitlab-ssh-secret` | SSH key pair and known_hosts for GitLab access |
| `ansible-ssh-key` | Automation SSH key for Ansible playbook execution |
| `semaphore-kubeconfig` | Kubeconfig for kubectl access from playbooks |
| `sops-age` | Age key for SOPS credential decryption |

## Storage

| PVC | Size | StorageClass | Purpose |
|-----|------|--------------|---------|
| `postgres-pvc` | 5Gi | NFS-client | PostgreSQL data |
| `ansible-repo-pvc` | 5Gi | NFS-client | Cloned homelab-Ansible repo |
| `semaphore-tmp-pvc` | 5Gi | NFS-client | Task execution working directory |
| `postgresql-backups` | 2Gi | NFS-client | Daily pg_dump backups |

All PVs use static NFS binding to TrueNAS paths under `/mnt/tank/kubernetes/`.

## Setup Jobs

### setup-GitLab-repo

Configures Semaphore via REST API after first deployment:
- Creates a "Homelab Infrastructure" project
- Creates HTTPS token key for GitLab access
- Creates inventory pointing to `inventory/hosts.yml`
- Creates repository pointing to homelab-Ansible
- Creates task templates for all major playbooks

### setup-tasks-schedules

Creates task templates and weekly schedules via direct PostgreSQL queries.

## Backup

Daily CronJob at 3 AM runs `pg_dump` with gzip compression. Retains 7 days of backups on NFS.

## Autoscaling

- **Semaphore VPA**: Auto mode (25m-500m CPU, 64Mi-512Mi memory)
- **PostgreSQL VPA**: Auto mode (25m-500m CPU, 64Mi-1Gi memory)

## Dependencies

- PostgreSQL 15 (in-namespace Deployment)
- GitLab (SSH access for repo clone)
- Authentik (OIDC SSO)
- SOPS Age key (credential decryption)
- Wildcard TLS certificate (`wildcard-tls`)
