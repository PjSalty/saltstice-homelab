# grafana/base/storage

Persistent storage for Grafana data (SQLite database, plugins, session data).

## Files

| File | Description |
|------|-------------|
| `pvc.yaml` | PersistentVolumeClaim (`grafana-data`) requesting 10Gi of storage via the `nfs-client` storage class with `ReadWriteOnce` access mode. |

## Storage Details

| Property | Value |
|----------|-------|
| Name | `grafana-data` |
| Storage class | `nfs-client` (NFS via the nfs-subdir-external-provisioner on TrueNAS) |
| Size | 10Gi |
| Access mode | ReadWriteOnce |
| Mount path | `/var/lib/grafana` (in the Deployment) |
