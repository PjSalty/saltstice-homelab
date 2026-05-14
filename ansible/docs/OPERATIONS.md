# Operations Guide

Day-2 operational playbooks for the Salty Homelab.

## Convergence

Run `site.yml` to bring all hosts to desired state:
```bash
ansible-playbook playbooks/site.yml
ansible-playbook playbooks/site.yml --limit infrastructure
ansible-playbook playbooks/site.yml --tags base
```

## Operations Playbooks

### Deploy Certificates
Extracts TLS certificates from cert-manager and deploys to VMs:
```bash
ansible-playbook playbooks/operations/deploy-certificates.yml
ansible-playbook playbooks/operations/deploy-certificates.yml --limit gitlab
```

### Patch Systems
Rolling OS updates (30% at a time):
```bash
ansible-playbook playbooks/operations/patch-systems.yml
ansible-playbook playbooks/operations/patch-systems.yml -e reboot=true
```

### Backup Verify
Checks etcd snapshots, Velero backups, and ZFS snapshots:
```bash
ansible-playbook playbooks/operations/backup-verify.yml
```

### Audit Config Drift
Compares live state against Ansible-defined state:
```bash
ansible-playbook playbooks/operations/audit-config-drift.yml
```

### Scale Cluster
Add or drain K8s nodes:
```bash
ansible-playbook playbooks/operations/scale-cluster.yml --limit k8s-worker-new
ansible-playbook playbooks/operations/scale-cluster.yml -e action=drain -e node=k8s-worker-3
```

### Rotate Credentials
```bash
ansible-playbook playbooks/operations/rotate-credentials.yml -e cred_mode=status
ansible-playbook playbooks/operations/rotate-credentials.yml -e cred_mode=dry-run
ansible-playbook playbooks/operations/rotate-credentials.yml -e cred_mode=rotate
```

## Semaphore Templates

| Template | Playbook | Schedule |
|----------|----------|----------|
| Converge All | `site.yml` | Manual |
| Deploy Certificates | `operations/deploy-certificates.yml` | Weekly Sun 3am |
| Patch Systems | `operations/patch-systems.yml` | Monthly 1st Sun 2am |
| Backup Verify | `operations/backup-verify.yml` | Daily 6am |
| Audit Drift | `operations/audit-config-drift.yml` | Weekly Sat 4am |
