# Bootstrap Guide

Full infrastructure bootstrap from bare Proxmox to production.

## Prerequisites

1. Proxmox hypervisor installed and accessible at `<mgmt-ip>`
2. Debian 13 (Trixie) cloud-init template (VM ID 9000) created
3. Terraform state backend configured
4. SSH key pair generated for automation
5. SOPS Age key available

## Bootstrap Phases

### Phase 0: Proxmox Configuration
```bash
ansible-playbook playbooks/phases/00-proxmox-config.yml
```
Hardens the Proxmox hypervisor: IOMMU, kernel modules, module blacklist.

### Phase 1: Terraform VMs
```bash
ansible-playbook playbooks/phases/01-terraform-vms.yml
```
Runs `terraform apply` to provision all VMs from the template. Waits for SSH accessibility.

### Phase 2: Base Configuration
```bash
ansible-playbook playbooks/phases/02-base-config.yml
```
Applies to all VMs: common packages, SSH hardening, UFW firewall, fail2ban, sudo, auto-updates, QEMU guest agent.

### Phase 3: Infrastructure Services
```bash
ansible-playbook playbooks/phases/03-infrastructure.yml
```
Installs Docker, deploys GitLab, Harbor, AMP, and VPN services.

### Phase 4: Load Balancers
```bash
ansible-playbook playbooks/phases/04-load-balancers.yml
```
Deploys HAProxy + keepalived HA pair with VIP <internal-ip> for K8s API load balancing.

### Phase 5: Kubernetes
```bash
ansible-playbook playbooks/phases/05-kubernetes.yml
```
Installs K8s prerequisites (kernel modules, sysctl), GPU drivers on workers, deploys RKE2 cluster via lablabs.RKE2 role.

### Phase 6: GitOps
```bash
ansible-playbook playbooks/phases/06-gitops.yml
```
Bootstraps FluxCD on the K8s cluster, connecting to the homelab-Kubernetes GitLab repo.

### Phase 7: Verification
```bash
ansible-playbook playbooks/phases/07-verify.yml
```
Validates: host connectivity, Docker daemon, HAProxy/keepalived, K8s nodes, FluxCD status.

## Full Bootstrap
```bash
ansible-playbook playbooks/bootstrap.yml
```
Runs all phases sequentially. Individual phases can be targeted with `--tags phase-XX`.
