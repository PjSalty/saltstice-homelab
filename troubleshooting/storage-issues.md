# Storage Issues Troubleshooting Guide

## Overview

Kubernetes storage problems: PVC mounts, NFS, and iSCSI connectivity.

## Quick Reference

| Issue | Symptom | First Check |
|-------|---------|-------------|
| PVC Pending | PVC not bound | StorageClass, CSI driver |
| Mount failed | Pod ContainerCreating | NFS/iSCSI connectivity |
| Read-only mount | Write errors | NFS export permissions |
| Stale mount | Commands hang | NFS server availability |
| Slow i/O | Performance issues | Network, disk utilization |

## PVC Issues

### PVC Stuck in Pending

```bash
# Check PVC status
kubectl get pvc -n <namespace>

# Get PVC details
kubectl describe pvc <pvc-name> -n <namespace>

# Check events
kubectl get events -n <namespace> --field-selector involvedObject.name=<pvc-name>
```

**StorageClass doesn't exist**:

```bash
# List storage classes
kubectl get storageclass

# Check PVC requests correct storageClass
kubectl get pvc <pvc-name> -n <namespace> -o yaml | grep storageClassName

# Fix: Use existing storageClass or create required one
```

**CSI driver not running**:

```bash
# Check democratic-csi pods
kubectl get pods -n democratic-csi

# Check CSI driver logs
kubectl logs -n democratic-csi deployment/democratic-csi-controller

# Restart CSI driver
kubectl rollout restart deployment/democratic-csi-controller -n democratic-csi
kubectl rollout restart daemonset/democratic-csi-node -n democratic-csi
```

**TrueNAS API unavailable**:

```bash
# Check TrueNAS is reachable
curl -s https://truenas.example.com/api/v2.0/system/info

# Check CSI secret has correct credentials
kubectl get secret -n democratic-csi truenas-api-key -o yaml

# Verify API token works
curl -s -H "Authorization: Bearer $TOKEN" \
  https://truenas.example.com/api/v2.0/pool
```

**Quota exceeded**:

```bash
# Check TrueNAS pool capacity
ssh truenas "zfs list"

# Check for orphaned volumes
kubectl get pv | grep Available

# Delete unused PVs if appropriate
```

### PVC Bound but Pod Can't Mount

```bash
# Check pod events
kubectl describe pod <pod-name> -n <namespace> | grep -A 20 Events

# Check PV details
kubectl get pv <pv-name> -o yaml

# Check mount on node
ssh <node> "mount | grep <pv-name>"
```

## NFS Issues

### Mount Failing

**Symptoms**:

- Pod stuck in `ContainerCreating`
- Events show "mount failed"

```bash
# Test NFS from node
ssh <node> "showmount -e truenas.example.com"

# Try manual mount
ssh <node> "mount -t nfs truenas.example.com:/mnt/tank/k8s/<pv> /tmp/test"

# Check NFS service on TrueNAS
ssh truenas "systemctl status nfs-server"
```

**NFS server not running**:

```bash
# Restart NFS
ssh truenas "systemctl restart nfs-server"

# Verify exports
ssh truenas "exportfs -v"
```

**Firewall blocking NFS**:

```bash
# Check NFS ports (2049, 111)
ssh <node> "nc -zv truenas.example.com 2049"

# Check firewall rules on TrueNAS
ssh truenas "iptables -L -n"
```

**Export permissions wrong**:

```bash
# Check export configuration
ssh truenas "cat /etc/exports"

# Verify client IP is allowed
# Fix: Update NFS share in TrueNAS to allow K8s node IPs
```

### Stale NFS Mounts

**Symptoms**:

- Commands hang
- `df` command hangs
- Pod stuck terminating

```bash
# Check for stale mounts
ssh <node> "mount | grep nfs"

# Force unmount stale mount
ssh <node> "umount -f /path/to/mount"

# If that fails, lazy unmount
ssh <node> "umount -l /path/to/mount"
```

**After unmount**:

```bash
# Delete stuck pod
kubectl delete pod <pod-name> -n <namespace> --force --grace-period=0

# Restart CSI node pod on affected node
kubectl delete pod -n democratic-csi -l app=democratic-csi-node --field-selector spec.nodeName=<node>
```

### Read-Only Mount

**Symptoms**:

- Write operations fail
- "Read-only file system" errors

```bash
# Check mount options
ssh <node> "mount | grep <mount-point>"

# Check NFS export options
ssh truenas "exportfs -v | grep <share>"

# Verify no_root_squash if needed (for containers running as root)
```

**Fix**:

```bash
# Update TrueNAS NFS share
# Set maproot_user and maproot_group appropriately

# Remount with correct options
ssh <node> "umount /path && mount -o rw,nfsvers=4 ..."

# Or delete pod to force remount
kubectl delete pod <pod-name> -n <namespace>
```

## iSCSI Issues

### iSCSI Target Not Connecting

```bash
# Check iSCSI sessions on node
ssh <node> "iscsiadm -m session"

# Check iSCSI discovery
ssh <node> "iscsiadm -m discovery -t sendtargets -p truenas.example.com"

# Check iSCSI service on TrueNAS
ssh truenas "systemctl status iscsitarget"
```

**No targets discovered**:

```bash
# Check TrueNAS iSCSI configuration
ssh truenas "targetcli ls"

# Verify target portal IP
# Should be on storage VLAN
```

**Authentication failure**:

```bash
# Check CHAP credentials in CSI config
kubectl get secret -n democratic-csi truenas-iscsi-creds -o yaml

# Verify credentials match TrueNAS configuration
```

### iSCSI Multipath Issues

```bash
# Check multipath status
ssh <node> "multipath -ll"

# If paths are failing, check network
ssh <node> "ping truenas-storage-ip"

# Restart multipathd
ssh <node> "systemctl restart multipathd"
```

## Performance Issues

### Slow i/O

**Diagnosis**:

```bash
# Check disk I/O on TrueNAS
ssh truenas "zpool iostat -v 1 5"

# Check network throughput
iperf3 -c truenas.example.com

# Check for ZFS pool issues
ssh truenas "zpool status -v"
```

**Common causes**:

- Network congestion (check switch)
- Disk degradation (check SMART)
- Pool near capacity (keep below 80%)
- Scrub running (wait for completion)

### Latency Issues

```bash
# Check for sync writes
# NFS async vs sync mount option affects latency

# Check ZFS sync setting
ssh truenas "zfs get sync <dataset>"

# For non-critical data, can set sync=disabled
# WARNING: Risk of data loss on power failure
```

## Volume Expansion

### Expand PVC

```bash
# Check if StorageClass allows expansion
kubectl get storageclass <sc> -o yaml | grep allowVolumeExpansion

# Edit PVC to increase size
kubectl edit pvc <pvc-name> -n <namespace>
# Change spec.resources.requests.storage

# Check expansion status
kubectl describe pvc <pvc-name> -n <namespace>
```

**If expansion fails**:

```bash
# Check CSI driver logs
kubectl logs -n democratic-csi deployment/democratic-csi-controller

# Some volumes require pod restart to recognize new size
kubectl delete pod <pod-using-pvc> -n <namespace>
```

## Volume Snapshots

### Create Snapshot

```bash
# Check VolumeSnapshotClass exists
kubectl get volumesnapshotclass

# Create snapshot
cat <<EOF | kubectl apply -f -
apiVersion: snapshot.storage.k8s.io/v1
kind: VolumeSnapshot
metadata:
  name: my-snapshot
  namespace: <namespace>
spec:
  volumeSnapshotClassName: democratic-csi-snapshotclass
  source:
    persistentVolumeClaimName: <pvc-name>
EOF

# Check snapshot status
kubectl get volumesnapshot -n <namespace>
```

### Restore from Snapshot

```bash
# Create PVC from snapshot
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: restored-pvc
  namespace: <namespace>
spec:
  storageClassName: <storage-class>
  dataSource:
    name: my-snapshot
    kind: VolumeSnapshot
    apiGroup: snapshot.storage.k8s.io
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 10Gi
EOF
```

## Debugging Commands

```bash
# List all PVCs and their status
kubectl get pvc -A

# List all PVs
kubectl get pv

# Check CSI driver pods
kubectl get pods -n democratic-csi

# Check CSI driver logs
kubectl logs -n democratic-csi deployment/democratic-csi-controller

# Check node CSI registration
kubectl get csinode

# List volume attachments
kubectl get volumeattachment
```

## Related Files

| File | Purpose |
|------|---------|
| `kubernetes/infrastructure/democratic-csi/` | CSI driver config |
| `ansible/playbooks/11-configure-truenas-k8s-nfs.yml` | NFS setup |
| `ansible/playbooks/12-configure-truenas-iscsi.yml` | iSCSI setup |
| [runbooks/storage-failure.md](../runbooks/storage-failure.md) | Storage failure recovery |
