# playbooks/

Ansible playbooks for bootstrapping, converging, and operating the Salty Homelab infrastructure.

## Structure

```
playbooks/
  bootstrap.yml              # Full infrastructure bootstrap (phases 0-7)
  site.yml                   # Day-2 convergence (idempotent, CI-driven)
  includes/
    load-ssot.yml            # Reusable SOPS credential loader
  phases/                    # Individual bootstrap phases
    00-proxmox-config.yml
    01-terraform-vms.yml
    02-base-config.yml
    03-infrastructure.yml
    04-load-balancers.yml
    05-kubernetes.yml
    06-gitops.yml
    07-verify.yml
  operations/                # Day-2 operations (manual/scheduled)
    audit-config-drift.yml
    backup-verify.yml
    deploy-automation-user.yml
    deploy-certificates.yml
    patch-systems.yml
    rolling-reboot.yml
    scale-cluster.yml
```

## site.yml -- Day-2 Convergence

The primary playbook run by GitLab CI on every merge to main. Safe to run repeatedly (idempotent). Applies the full desired state across all hosts.

### Execution Order

1. Load SSOT credentials (decrypts `credentials.sops.yaml` once, distributes to all hosts)
3. Proxmox hypervisor hardening
4. Infrastructure services (Docker + certificates on GitLab, Harbor, NetBox)
5. GitLab, Harbor, NetBox deployments (individually)
6. DNS, load balancers, K8s prerequisites, GPU drivers
8. Storage certificates, TLS certificate deployment

### Pre-tasks

Before applying base roles, site.yml removes conflicting APT sources and GPG keys (Grafana, NVIDIA, Docker) that may have been left by previous manual installations. This makes sure a clean state for the Docker, GPU, and Promtail roles.

### Usage

```bash
ansible-playbook playbooks/site.yml                          # Full convergence
ansible-playbook playbooks/site.yml --tags base              # Base OS only
ansible-playbook playbooks/site.yml --limit infrastructure   # Docker hosts only
ansible-playbook playbooks/site.yml --limit gitlab --tags gitlab  # GitLab only
```

## bootstrap.yml -- Full Bootstrap

Runs all 8 phases sequentially to bring a bare Proxmox host to a fully operational infrastructure. Individual phases can be targeted with `--tags phase-XX`.

```bash
ansible-playbook playbooks/bootstrap.yml                # Full bootstrap
ansible-playbook playbooks/bootstrap.yml --tags phase-05  # K8s only
```

## includes/

### load-ssot.yml

Reusable credential loader imported at the top of any playbook needing SOPS credentials. Decrypts `credentials.sops.yaml` once on localhost, then distributes the `creds` fact to all hosts. Works correctly with `--limit` via `run_once` + `delegate_to`.

The SSOT file location defaults to `credentials/credentials.sops.yaml` relative to the playbooks directory, but can be overridden with the `SSOT_FILE` environment variable.

## phases/

### 00-Proxmox-config.yml

Configures the Proxmox hypervisor: IOMMU, kernel module blacklists, GPU passthrough preparation. Runs the `proxmox` role against the Proxmox host group.

### 01-Terraform-vms.yml

Runs `terraform apply` against the homelab-Terraform directory to provision all VMs from cloud-init templates. Waits for SSH connectivity on all newly created VMs (300s timeout).

### 02-base-config.yml

### 03-infrastructure.yml

Deploys Docker and service-specific roles on infrastructure VMs. Loads SSOT credentials first, then deploys GitLab, Harbor, AMP, and VPN services.

### 04-load-balancers.yml

Deploys HAProxy + keepalived HA pair for Kubernetes API load balancing. Loads SSOT credentials for HAProxy stats and keepalived auth passwords.

### 05-Kubernetes.yml

Three-stage K8s deployment: prerequisites (kernel modules, sysctl), GPU drivers on workers, RKE2 cluster deployment via the lablabs.RKE2 role.

### 06-GitOps.yml

Bootstraps FluxCD on the first master node. Checks if Flux is already installed before running `flux bootstrap gitlab`. Requires `GITLAB_TOKEN` environment variable.

### 07-verify.yml

Validates the entire infrastructure: host connectivity (ping), Docker daemon on infrastructure hosts, HAProxy + keepalived active on load balancers, K8s node status, FluxCD Kustomization status.

## operations/

### audit-config-drift.yml

Compares live state against expected Ansible-defined state. Checks SSH hardening config, UFW status, sysctl hardening, user accounts, running services, and open ports. Reports PASS/DRIFT per check.

### backup-verify.yml

Verifies backup health across three systems:
- etcd snapshots (must exist within last 24 hours)
- Velero backups (checks status phases)
- ZFS snapshots on TrueNAS (lists recent snapshots)

### deploy-automation-user.yml

One-time bootstrap of the `automation` user account on all VMs. After running, CI/CD can connect as the automation user with full NOPASSWD sudo. Updates sshd AllowUsers to include the automation account.

### deploy-certificates.yml

Deploys TLS certificates from cert-manager to infrastructure VMs, DNS servers, load balancers, storage, and Proxmox. Uses the `certificates` role to place certs at service-specific paths.

### patch-systems.yml

Rolling OS updates at 30% concurrency. Updates apt cache, runs `apt upgrade safe`, checks for reboot requirement. Only reboots if explicitly enabled with `-e reboot=true`.

### rolling-reboot.yml

Graceful rolling reboot across all VMs in 5 phases:
1. Infrastructure VMs (serial: 1)
2. HAProxy load balancers (serial: 1, with VIP failover pause)
3. K8s workers (drain, reboot, wait for Ready, uncordon, pause for rescheduling)
4. K8s masters (verify etcd quorum, drain, reboot, wait, uncordon, wait for etcd rejoin)
5. Final cluster health verification

### scale-cluster.yml

Adds or removes K8s nodes. Prepares new nodes with all base roles + K8s-prereqs, then joins via lablabs.RKE2. Also supports draining a specific node with `-e action=drain -e node=k8s-worker-3`.
