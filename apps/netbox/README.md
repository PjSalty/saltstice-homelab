# NetBox (DEPRECATED - VM Deployment)

**WARNING: This Kubernetes deployment is DEPRECATED and NOT in use.**

NetBox runs as a VM at `<internal-ip>` (`netbox.example.com`), managed by Ansible. This directory is retained for historical reference only.

## Current NetBox Deployment

- **URL**: `http://<internal-ip>` (Host: `netbox.example.com`)
- **Deployed via**: `ansible/playbooks/07-deploy-netbox.yml`
- **Plugin installation**: `ansible/playbooks/28-netbox-install-dns-plugin.yml`
- **Version**: v4.4.6 with NetBox-plugin-DNS v1.4.4

## Directory Structure (Reference Only)

```
kustomization.yaml                          - Top-level kustomization (DO NOT APPLY)
base/
  kustomization.yaml                        - Base kustomization listing all resources
  namespace.yaml                            - Namespace definition
  deployments/
    netbox-deployment.yaml                  - NetBox app, worker, PostgreSQL, Redis deployments
  ingress/
    netbox-ingress.yaml                     - Traefik Ingress for netbox.example.com
  configmaps/
    netbox-config.yaml                      - SOPS-encrypted environment config (DB, OIDC)
    netbox-extra-config.yaml                - Python plugin config (DNS plugin, Authentik OIDC)
    netbox-scripts.yaml                     - Population and DNS sync Python scripts
    ansible-inventory.yaml                  - Infrastructure inventory for NetBox population
  configs/
    discovery-script.yaml                   - IP discovery and auto-population script
  secrets/
    netbox-secret.yaml                      - SOPS-encrypted DB password, secret key, API token
    netbox-admin-secret.yaml                - SOPS-encrypted admin username/password/email
    automation-tokens.yaml                  - SOPS-encrypted NetBox and GitLab API tokens
    adguard-credentials.yaml                - SOPS-encrypted AdGuard Home admin credentials
  jobs/
    netbox-init-job.yaml                    - One-time infrastructure population job
    netbox-ip-discovery.yaml                - CronJob for network scanning (every 15 min)
  cronjobs/
    netbox-dns-sync.yaml                    - CronJob syncing DNS from NetBox to AdGuard (every 15 min)
```

## What This Would Have Done

The K8s deployment included:
- NetBox v4.4.6 with DNS plugin
- PostgreSQL 16 StatefulSet (NFS storage)
- Redis for caching
- Authentik OIDC SSO integration
- Automated IP discovery via nmap scanning
- DNS synchronization from NetBox to AdGuard Home
- Infrastructure population from Ansible inventory
