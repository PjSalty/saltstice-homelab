# Disaster Recovery Runbook

## Overview

This runbook covers disaster recovery procedures for the Salty Homelab infrastructure. The homelab is designed for single-bootstrap rebuildability - any component can be rebuilt from scratch using Terraform, Ansible, and FluxCD.

## Recovery Priority Order

| Priority | Component | RTO | RPO | Recovery Method |
|----------|-----------|-----|-----|-----------------|
| 1 | Proxmox Hypervisor | 4h | N/A | Bare metal reinstall |
| 2 | TrueNAS Storage | 2h | 24h | ZFS import or backup restore |
| 3 | AdGuard DNS | 30m | N/A | Terraform + Ansible |
| 4 | HAProxy Load Balancer | 30m | N/A | Terraform + Ansible |
| 5 | Kubernetes Cluster | 2h | 1h | RKE2 rebuild + Flux |
| 6 | GitLab | 1h | 24h | Terraform + Ansible + backup |
| 7 | Harbor Registry | 1h | 24h | Terraform + Ansible |
| 8 | All Other Services | 1h | Varies | FluxCD reconciliation |

**RTO** = Recovery Time Objective (target time to restore)
**RPO** = Recovery Point Objective (acceptable data loss window)

## Scenario 1: Single VM Failure

### Symptoms

- VM unreachable
- Service unavailable
- Proxmox shows VM stopped/crashed

### Recovery Steps

1. **Assess the situation**:

   ```bash
   # Check VM status in Proxmox
   ssh proxmox "qm status <VMID>"

   # Check recent events
   ssh proxmox "qm status <VMID> --verbose"
   ```

2. **Attempt restart**:

   ```bash
   ssh proxmox "qm start <VMID>"
   ```

3. **If restart fails, rebuild VM**:

   ```bash
   # Destroy failed VM (if needed)
   # WARNING: Make sure data is backed up first

   # Rebuild via Terraform
   cd terraform
   terraform apply -target=module.<vm_name>

   # Configure via Ansible
   ansible-playbook ansible/playbooks/<service>-deploy.yml
   ```

4. **For Kubernetes nodes**:

   ```bash
   # Remove failed node from cluster
   kubectl delete node <node-name>

   # Rebuild and rejoin
   terraform apply -target=module.k8s_worker_<n>
   ansible-playbook ansible/playbooks/rke2-join-worker.yml -l <node>
   ```

## Scenario 2: Kubernetes Cluster Failure

### Complete Cluster Loss

1. **Rebuild infrastructure**:

   ```bash
   # Rebuild HAProxy (API load balancer)
   terraform apply -target=module.haproxy
   ansible-playbook ansible/playbooks/08-deploy-haproxy.yml

   # Rebuild master nodes
   terraform apply -target=module.k8s_master_1
   terraform apply -target=module.k8s_master_2
   terraform apply -target=module.k8s_master_3

   # Initialize first master
   ansible-playbook ansible/playbooks/kubernetes.yml -l k8s_master_1

   # Join additional masters
   ansible-playbook ansible/playbooks/kubernetes.yml -l k8s_masters

   # Rebuild and join workers
   terraform apply -target=module.k8s_workers
   ansible-playbook ansible/playbooks/rke2-join-worker.yml
   ```

2. **Restore Flux GitOps**:

   ```bash
   # Bootstrap FluxCD
   ansible-playbook ansible/playbooks/09-bootstrap-fluxcd.yml

   # Flux will automatically reconcile all applications from Git
   flux get kustomizations -A
   ```

3. **Restore secrets**:

   ```bash
   # Secrets are in infrastructure/secrets repo
   # SOPS decryption happens automatically via Flux
   kubectl get secrets -A | grep -v default-token
   ```

4. **Verify applications**:

   ```bash
   # Check all pods
   kubectl get pods -A

   # Check Flux reconciliation
   flux get all -A
   ```

### Single Master Failure (Cluster Still Operational)

1. **Remove failed master**:

   ```bash
   kubectl delete node k8s-master-<n>
   ```

2. **Rebuild master**:

   ```bash
   terraform apply -target=module.k8s_master_<n>
   ansible-playbook ansible/playbooks/kubernetes.yml -l k8s_master_<n>
   ```

3. **Verify etcd cluster**:

   ```bash
   kubectl -n kube-system exec -it etcd-k8s-master-1 -- \
     etcdctl member list --cacert=/etc/kubernetes/pki/etcd/ca.crt \
     --cert=/etc/kubernetes/pki/etcd/server.crt \
     --key=/etc/kubernetes/pki/etcd/server.key
   ```

## Scenario 3: Storage Failure (TrueNAS)

### ZFS Pool Degraded

1. **Check pool status**:

   ```bash
   ssh truenas "zpool status"
   ```

2. **Replace failed disk**:

   ```bash
   # Identify failed disk
   ssh truenas "zpool status -v"

   # Replace disk (physical replacement required first)
   ssh truenas "zpool replace <pool> <old-disk> <new-disk>"
   ```

3. **Monitor resilver**:

   ```bash
   ssh truenas "zpool status -v"
   # Wait for resilver to complete
   ```

### Complete TrueNAS VM Failure

1. **Check if ZFS pool is importable**:

   ```bash
   # From Proxmox, check if disks are visible
   ssh proxmox "lsblk"
   ```

2. **Rebuild TrueNAS VM**:

   ```bash
   # Use DANGEROUS playbook only if pool import fails
   # Otherwise, rebuild VM and import existing pool

   terraform apply -target=module.truenas
   ansible-playbook ansible/playbooks/01-import-truenas-pool.yml
   ```

3. **Verify NFS exports**:

   ```bash
   showmount -e truenas.example.com
   ```

4. **Restart Kubernetes workloads using storage**:

   ```bash
   kubectl rollout restart deployment -n <namespace> <deployment>
   ```

## Scenario 4: Complete Site Failure

### Prerequisites

- Off-site backup of:
 - Git repositories (GitLab backup or GitHub mirror)
 - TrueNAS ZFS snapshots (replicated off-site)
 - `secrets/credentials.sops.yaml`
 - SOPS Age keys

### Recovery Steps

1. **Reinstall Proxmox** on bare metal

2. **Restore network configuration**:

   ```bash
   ansible-playbook ansible/playbooks/00-proxmox-network.yml
   ```

3. **Deploy TrueNAS and restore data**:

   ```bash
   # Deploy TrueNAS VM
   terraform apply -target=module.truenas

   # Restore from off-site backup
   # (Specific steps depend on backup location)
   ```

4. **Deploy core infrastructure**:

   ```bash
   # Deploy in order
   ansible-playbook ansible/playbooks/deploy-complete-infrastructure.yml
   ```

5. **Bootstrap Kubernetes and Flux**:

   ```bash
   ansible-playbook ansible/playbooks/kubernetes.yml
   ansible-playbook ansible/playbooks/09-bootstrap-fluxcd.yml
   ```

6. **Verify all services**:

   ```bash
   # Check all Flux resources
   flux get all -A

   # Check all pods
   kubectl get pods -A

   # Run health checks
   ./scripts/health-check.sh
   ```

## Backup Verification

### Regular Backup Checks

```bash
# Check TrueNAS snapshots
ssh truenas "zfs list -t snapshot"

# Check GitLab backups
ssh gitlab "ls -la /var/opt/gitlab/backups/"

# Check Velero backups (Kubernetes)
velero backup get

# Verify SOPS can decrypt
sops -d secrets/credentials.sops.yaml > /dev/null && echo "SOPS OK"
```

### Backup Restoration Test (Quarterly)

1. Create isolated test environment
2. Restore from backups
3. Verify data integrity
4. Document any issues
5. Update runbook as needed

## Emergency Contacts

| Role | Contact | When to Escalate |
|------|---------|------------------|
| Primary Admin | (contact) | Any P1 incident |
| Hardware Support | (contact) | Physical failures |
| ISP | (contact) | Network outages |

## Post-Incident

After any disaster recovery:

1. **Document the incident**:
 - What failed?
 - Root cause?
 - Recovery time actual vs target?
 - What could be improved?

2. **Update runbooks** with lessons learned

3. **Review and test backups**

4. **Consider additional redundancy** if needed

## Related Files

| File | Purpose |
|------|---------|
| `ansible/playbooks/deploy-complete-infrastructure.yml` | Full infrastructure deployment |
| `ansible/playbooks/kubernetes.yml` | Kubernetes cluster setup |
| `ansible/playbooks/09-bootstrap-fluxcd.yml` | FluxCD bootstrap |
| `terraform/` | Infrastructure as Code |
| `docs/runbooks/backup-restore.md` | Detailed backup procedures |
