# VM Certificate Management

CronJob and RBAC for syncing the cluster's wildcard TLS certificate to infrastructure VMs (GitLab, Harbor, Proxmox, TrueNAS). This bridges the Kubernetes certificate lifecycle with non-Kubernetes infrastructure.

The cert-manager controller itself is deployed in `infrastructure/controllers/cert-manager/`. This directory handles the post-issuance distribution of certificates to VMs.

## Directory Structure

```
cert-manager/
  vm-certificates/
    kustomization.yaml        # Aggregates all resources
    namespace.yaml            # Namespace vm-certificates
    cert-sync-cronjob.yaml    # CronJob, ServiceAccount, ClusterRole, RoleBinding
    ci-runner-rbac.yaml       # RBAC for CI/CD pipeline cert extraction
```

Deployed by the `vm-certificates` Flux Kustomization from `clusters/homelab/infrastructure-kustomizations.yaml`, which depends on `cert-manager`.

## How It Works

1. **cert-manager** issues and renews the wildcard certificate (`*.example.com`) via Let's Encrypt DNS-01
2. The certificate Secret (`wildcard-tls`) lives in the `cert-manager` namespace
3. The **cert-sync CronJob** in the `vm-certificates` namespace:
 - Reads the `wildcard-tls` Secret from the `cert-manager` namespace (via ClusterRole)
 - Extracts the certificate and private key
 - Deploys them to infrastructure VMs via SCP/SSH
4. The **CI/CD pipeline** (`ansible:deploy-certs` job) can also extract and deploy certs using the RBAC defined in `ci-runner-rbac.yaml`

## Target VMs

| VM | Certificate Path | Service |
|----|-----------------|---------|
| GitLab | `/data/gitlab/config/ssl/` | GitLab HTTPS |
| Harbor | `/data/harbor/secret/cert/` | Harbor registry HTTPS |
| Proxmox | `/etc/pve/local/` | Proxmox web UI |
| TrueNAS | Via API | TrueNAS web UI |
