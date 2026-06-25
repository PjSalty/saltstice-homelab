# prometheus/base/storage

Persistent storage for the Prometheus time-series database.

## Files

| File | Description |
|------|-------------|
| `pvc.yaml` | PersistentVolumeClaim (`prometheus-data`) requesting 50Gi of storage via the `nfs-client` storage class with `ReadWriteOnce` access mode. |

## Storage Details

| Property | Value |
|----------|-------|
| Name | `prometheus-data` |
| Storage class | `nfs-client` (NFS via the nfs-subdir-external-provisioner on TrueNAS) |
| Size | 50Gi |
| Access mode | ReadWriteOnce |
| Mount path | `/prometheus` (in the Deployment) |

## Retention Policy

The Prometheus server is configured with dual retention limits (set in the Deployment args):
- **Time-based**: 15 days (`--storage.tsdb.retention.time=15d`)
- **Size-based**: 45GB (`--storage.tsdb.retention.size=45GB`)

Whichever limit is reached first triggers data compaction and removal.
