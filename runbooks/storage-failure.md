# Storage Failure Runbook

## Overview

TrueNAS and ZFS failure scenarios. Every K8s persistent volume and VM disk depends on this storage, so treat it as critical.

## Architecture

```
┌┐
                         TrueNAS                                  
                    (<internal-ip>)                                
┤
                                                                  
  ┌┐    ┌┐                  
     boot-pool             tank (data)                      
     (OS only)             RAIDZ2                           
  ┘    ┘                  
                                                                 
            ┌┼┐      
                                                              
     ┌▼┐       ┌▼┐       ┌▼┐
          NFS                iSCSI                SMB     
        exports             targets             shares    
     ┘       ┘       ┘
                                                              
┼┼┼┘
                                                         
      ┌▼┐       ┌▼┐       ┌▼┐
       Kubernetes          Kubernetes             VMs/     
       NFS PVCs            iSCSI PVCs            Clients   
       (truenas            (truenas                        
          -csi)               -csi)                        
      ┘       ┘       ┘
```

## Quick Diagnosis

```bash
# Check TrueNAS is reachable
ping truenas.example.com

# Check ZFS pool status
ssh truenas "zpool status"

# Check ZFS pool capacity
ssh truenas "zpool list"
ssh truenas "zfs list"

# Check NFS exports
showmount -e truenas.example.com

# Check iSCSI targets
ssh truenas "targetcli ls"

# Check Kubernetes PVCs
kubectl get pvc -A
```

## Scenario 1: TrueNAS VM Unreachable

### Symptoms

- Cannot ping TrueNAS
- NFS mounts hanging
- Kubernetes pods stuck in `ContainerCreating`
- PVCs showing as unavailable

### Immediate Actions

1. **Check VM status in Proxmox**:

   ```bash
   ssh proxmox "qm status <truenas-vmid>"
   ```

2. **Check if VM is running but network issue**:

   ```bash
   # Access via Proxmox console
   ssh proxmox "qm terminal <truenas-vmid>"
   ```

3. **Restart TrueNAS VM** (if safe):

   ```bash
   ssh proxmox "qm reboot <truenas-vmid>"
   ```

4. **After TrueNAS is back**:

   ```bash
   # Verify pool status
   ssh truenas "zpool status"

   # Restart NFS service
   ssh truenas "systemctl restart nfs-server"

   # Restart affected Kubernetes pods
   kubectl delete pods -A --field-selector status.phase=Pending
   ```

## Scenario 2: ZFS Pool Degraded

### Symptoms

- `zpool status` shows `DEGRADED`
- One or more disks showing `FAULTED` or `OFFLINE`
- Email alert from TrueNAS

### Diagnosis

```bash
# Check detailed pool status
ssh truenas "zpool status -v"

# Identify failed disk
ssh truenas "zpool status tank | grep -E 'FAULTED|DEGRADED|OFFLINE'"

# Check disk SMART data
ssh truenas "smartctl -a /dev/disk/by-id/<disk-id>"
```

### Recovery

**For single disk failure in RAIDZ2** (pool remains operational):

1. **Order replacement disk** (match specs)

2. **Physical replacement**:
 - Hot-swap if supported
 - Otherwise, schedule maintenance window

3. **Replace disk in ZFS**:

   ```bash
   # Identify new disk
   ssh truenas "lsblk"

   # Replace failed disk
   ssh truenas "zpool replace tank <old-disk-id> <new-disk-id>"
   ```

4. **Monitor resilver progress**:

   ```bash
   ssh truenas "zpool status tank"
   # Resilver can take hours depending on data size
   ```

**For multiple disk failures** (beyond RAIDZ2 tolerance):

1. **DO NOT REBOOT** - may lose data
2. **Assess damage**:

   ```bash
   ssh truenas "zpool status -v tank"
   ```

3. **If pool is still mounted**, backup critical data immediately
4. **Contact storage expert** for recovery options
5. **Restore from backup** if pool is lost

## Scenario 3: Pool Full

### Symptoms

- Applications failing to write
- `zpool list` shows >90% capacity
- Alerts firing for disk space

### Immediate Actions

1. **Check usage**:

   ```bash
   ssh truenas "zfs list -o name,used,avail,refer"
   ```

2. **Find large datasets**:

   ```bash
   ssh truenas "zfs list -o name,used -s used | tail -20"
   ```

3. **Check snapshot usage**:

   ```bash
   ssh truenas "zfs list -t snapshot -o name,used -s used | tail -20"
   ```

4. **Delete old snapshots** (if safe):

   ```bash
   # List snapshots older than 30 days
   ssh truenas "zfs list -t snapshot -o name,creation | grep '30 days'"

   # Delete specific snapshot
   ssh truenas "zfs destroy tank/data@old-snapshot"
   ```

5. **Expand pool** (if possible):
 - Add new vdev
 - Replace disks with larger ones (one at a time, wait for resilver)

## Scenario 4: NFS Mount Issues

### Symptoms

- Kubernetes pods failing to mount PVCs
- `showmount -e` fails or times out
- Existing mounts become read-only or hang

### Diagnosis

```bash
# Check NFS service
ssh truenas "systemctl status nfs-server"

# Check NFS exports
ssh truenas "exportfs -v"

# Check from client
showmount -e truenas.example.com

# Check for stale mounts on nodes
ssh k8s-worker-1 "mount | grep nfs"
```

### Recovery

1. **Restart NFS service**:

   ```bash
   ssh truenas "systemctl restart nfs-server"
   ```

2. **Force unmount stale mounts** (on affected nodes):

   ```bash
   ssh <node> "umount -f /path/to/mount"
   ```

3. **Restart truenas-csi**:

   ```bash
   kubectl rollout restart deployment/truenas-csi-controller -n truenas-csi
   kubectl rollout restart daemonset/truenas-csi-node -n truenas-csi
   ```

4. **Recreate affected pods**:

   ```bash
   kubectl delete pods -A --field-selector status.phase=Pending
   ```

## Scenario 5: iSCSI Target Issues

### Symptoms

- iSCSI PVCs not mounting
- Pods stuck in `ContainerCreating`
- `iscsiadm` commands failing

### Diagnosis

```bash
# Check iSCSI service on TrueNAS
ssh truenas "systemctl status iscsitarget"

# Check targets
ssh truenas "targetcli ls"

# Check from node
ssh k8s-worker-1 "iscsiadm -m session"
```

### Recovery

1. **Restart iSCSI target service**:

   ```bash
   ssh truenas "systemctl restart iscsitarget"
   ```

2. **On affected nodes**, restart iSCSI initiator:

   ```bash
   ssh <node> "systemctl restart iscsid"
   ```

3. **Rescan sessions**:

   ```bash
   ssh <node> "iscsiadm -m session --rescan"
   ```

## Scenario 6: Data Corruption

### Symptoms

- Applications reporting data errors
- ZFS shows checksum errors
- `zpool status` shows `CKSUM` errors

### Diagnosis

```bash
# Check for errors
ssh truenas "zpool status -v"

# Run scrub to find all errors
ssh truenas "zpool scrub tank"

# Monitor scrub progress
ssh truenas "zpool status tank | grep scan"
```

### Recovery

1. **Let scrub complete** to find all errors

2. **If errors are repairable** (ZFS fixed them):

   ```bash
   # Clear error counters after scrub
   ssh truenas "zpool clear tank"
   ```

3. **If errors persist**:
 - Check disk health with SMART
 - Replace failing disk
 - Restore affected files from backup

## Preventive Measures

### Regular Checks

```bash
# Weekly scrub (usually automated)
ssh truenas "zpool scrub tank"

# Check SMART status monthly
ssh truenas "smartctl -a /dev/sdX"

# Monitor pool capacity
ssh truenas "zpool list"
```

### Monitoring

TrueNAS should have:

- [ ] Email alerts configured
- [ ] SMART monitoring enabled
- [ ] Prometheus metrics exported
- [ ] Grafana dashboard for storage

### Backup Strategy

- ZFS snapshots (local, automated)
- Replication to secondary pool (if available)
- Off-site backup for critical data

## Post-Incident Checklist

After any storage incident:

- [ ] Pool status is `ONLINE` and `HEALTHY`
- [ ] All NFS exports accessible
- [ ] All iSCSI targets connected
- [ ] Kubernetes PVCs bound and working
- [ ] No data loss confirmed
- [ ] Root cause identified
- [ ] Preventive measures set up
- [ ] Incident documented

## Related Files

| File | Purpose |
|------|---------|
| `ansible/playbooks/01-import-truenas-pool.yml` | Pool import |
| `ansible/playbooks/11-configure-truenas-k8s-nfs.yml` | NFS setup |
| `ansible/playbooks/12-configure-truenas-iscsi.yml` | iSCSI setup |
| `kubernetes/infrastructure/truenas-csi/` | CSI driver config (csi.truenas.io) |
| `docs/runbooks/disaster-recovery.md` | Full DR procedures |
