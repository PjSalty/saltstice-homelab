# Backup and Restore Runbook

## Overview


## Backup Architecture

```
┌┐
                        BACKUP SOURCES                                
┤
                                                                      
  ┌┐  ┌┐  ┌┐              
     TrueNAS         GitLab         Kubernetes                
    ZFS Snaps        Backups          Velero                  
  ┬┘  ┬┘  ┬┘              
                                                                   
         ▼                 ▼                 ▼                        
  ┌┐           
                TrueNAS Backup Pool                                
           (ZFS snapshots + replication)                           
  ┘           
                                                                      
┘
```

## Backup Schedules

| Data | Method | Frequency | Retention | Location |
|------|--------|-----------|-----------|----------|
| TrueNAS datasets | ZFS snapshots | Hourly | 24h hourly, 7d daily, 4w weekly | Local pool |
| GitLab | GitLab-backup | Daily 2 AM | 7 days | TrueNAS NFS |
| Kubernetes PVCs | Velero | Daily 3 AM | 7 days | TrueNAS NFS |
| VM configs | Proxmox backup | Weekly | 4 weeks | TrueNAS NFS |
| Secrets SSOT | Git + SOPS | On change | Git history | GitLab |

## Checking Backup Status

### TrueNAS ZFS Snapshots

```bash
# List all snapshots
ssh truenas "zfs list -t snapshot -o name,creation,used -s creation"

# List snapshots for specific dataset
ssh truenas "zfs list -t snapshot -r tank/data"

# Check snapshot schedule (via TrueNAS API)
curl -s -X GET "https://truenas.example.com/api/v2.0/pool/snapshottask" \
  -H "Authorization: Bearer $TRUENAS_API_TOKEN" | jq
```

### GitLab Backups

```bash
# List GitLab backups
ssh gitlab "ls -lah /var/opt/gitlab/backups/"

# Check backup cron
ssh gitlab "crontab -l | grep backup"

# Verify latest backup integrity
ssh gitlab "gitlab-backup verify BACKUP=<timestamp>"
```

### Velero (Kubernetes)

```bash
# List all backups
velero backup get

# Describe specific backup
velero backup describe <backup-name> --details

# Check backup schedule
velero schedule get

# View backup logs
velero backup logs <backup-name>
```

### Proxmox VM Backups

```bash
# List VM backups
ssh proxmox "ls -la /var/lib/vz/dump/"

# Check backup schedule in Proxmox GUI
# Datacenter  Backup  Backup Jobs
```

## Restoration Procedures

### Restore TrueNAS ZFS Snapshot

**Restore entire dataset**:

```bash
# WARNING: This replaces current data
ssh truenas "zfs rollback tank/data@<snapshot-name>"
```

**Restore specific files** (recommended):

```bash
# Mount snapshot read-only
ssh truenas "mount -t zfs tank/data@<snapshot-name> /mnt/restore"

# Copy specific files
ssh truenas "cp /mnt/restore/path/to/file /tank/data/path/to/file"

# Unmount
ssh truenas "umount /mnt/restore"
```

**Clone snapshot for testing**:

```bash
# Create clone from snapshot
ssh truenas "zfs clone tank/data@<snapshot-name> tank/restore-test"

# Access at /mnt/tank/restore-test
# Delete when done
ssh truenas "zfs destroy tank/restore-test"
```

### Restore GitLab Backup

1. **Stop GitLab services**:

   ```bash
   ssh gitlab "gitlab-ctl stop puma"
   ssh gitlab "gitlab-ctl stop sidekiq"
   ```

2. **Restore from backup**:

   ```bash
   # List available backups
   ssh gitlab "ls /var/opt/gitlab/backups/"

   # Restore (replace TIMESTAMP with actual value)
   ssh gitlab "gitlab-backup restore BACKUP=<TIMESTAMP>_gitlab_backup"
   ```

3. **Restore secrets** (if needed):

   ```bash
   # Restore gitlab-secrets.json from secure backup
   scp backup/gitlab-secrets.json gitlab:/etc/gitlab/
   ```

4. **Reconfigure and restart**:

   ```bash
   ssh gitlab "gitlab-ctl reconfigure"
   ssh gitlab "gitlab-ctl restart"
   ```

5. **Verify**:

   ```bash
   ssh gitlab "gitlab-rake gitlab:check SANITIZE=true"
   ```

### Restore Kubernetes Resources (Velero)

**Restore entire backup**:

```bash
velero restore create --from-backup <backup-name>
```

**Restore specific namespace**:

```bash
velero restore create --from-backup <backup-name> \
  --include-namespaces <namespace>
```

**Restore specific resources**:

```bash
velero restore create --from-backup <backup-name> \
  --include-resources persistentvolumeclaims,persistentvolumes \
  --include-namespaces <namespace>
```

**Check restore status**:

```bash
velero restore get
velero restore describe <restore-name> --details
```

### Restore Proxmox VM

1. **From Proxmox GUI**:
 - Datacenter Storage Select backup storage
 - Select VM backup file
 - Click "Restore"
 - Choose target node and VM ID

2. **From CLI**:

   ```bash
   # List available backups
   ssh proxmox "ls /var/lib/vz/dump/"

   # Restore VM
   ssh proxmox "qmrestore /var/lib/vz/dump/vzdump-qemu-<VMID>-<DATE>.vma <NEW-VMID>"
   ```

### Restore Secrets

**From Git history**:

```bash
# View SOPS file history
git log --oneline secrets/credentials.sops.yaml

# Restore specific version
git checkout <commit-hash> -- secrets/credentials.sops.yaml

# Decrypt to verify
sops -d secrets/credentials.sops.yaml
```

**From Vaultwarden** (manual credentials):

- Log into Vault.example.com
- Navigate to relevant folder
- Copy credentials as needed

## Backup Verification Checklist

### Daily (Automated)

- [ ] TrueNAS snapshot jobs completed
- [ ] GitLab backup created
- [ ] Velero backup succeeded
- [ ] No backup alerts in Prometheus

### Weekly (Manual)

- [ ] Verify GitLab backup can be listed
- [ ] Check Velero backup count matches retention
- [ ] Review backup storage usage
- [ ] Test decrypt SOPS secrets file

### Monthly

- [ ] Restore test: GitLab (to test instance)
- [ ] Restore test: Random Velero backup
- [ ] Verify off-site backup sync (if configured)
- [ ] Review and update backup retention policies

### Quarterly

- [ ] Full DR test: Restore entire environment
- [ ] Document restoration times
- [ ] Update this runbook with lessons learned

## Troubleshooting

### GitLab Backup Fails

```bash
# Check disk space
ssh gitlab "df -h /var/opt/gitlab/backups"

# Check GitLab logs
ssh gitlab "gitlab-ctl tail"

# Manual backup with verbose output
ssh gitlab "gitlab-backup create STRATEGY=copy"
```

### Velero Backup Fails

```bash
# Check Velero pod logs
kubectl logs -n velero deployment/velero

# Check for PVC issues
velero backup describe <backup-name> --details

# Verify storage location
velero backup-location get
```

### ZFS Snapshot Fails

```bash
# Check pool status
ssh truenas "zpool status"

# Check available space
ssh truenas "zfs list -o name,used,avail"

# Check snapshot task logs in TrueNAS GUI
# System  Advanced  Cron Jobs
```

## Related Files

| File | Purpose |
|------|---------|
| `kubernetes/apps/velero/` | Velero configuration |
| `ansible/roles/gitlab/tasks/backup.yml` | GitLab backup setup |
| `docs/runbooks/disaster-recovery.md` | Full DR procedures |
