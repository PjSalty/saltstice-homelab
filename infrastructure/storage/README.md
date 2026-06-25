# NFS Storage

NFS CSI driver and StorageClass definitions for shared file storage backed by TrueNAS. This provides the default StorageClass (`nfs-client`) used by most application PVCs.

Deployed by the `nfs-storage` Flux Kustomization from `clusters/homelab/infrastructure-kustomizations.yaml`.

## Files

| File | Resources | Purpose |
|------|-----------|---------|
| `nfs-csi-driver.yaml` | Namespace `nfs-system`, ServiceAccount, ClusterRole, ClusterRoleBinding, Role, RoleBinding, Deployment, StorageClass | Complete NFS-subdir-external-provisioner deployment with RBAC and the `nfs-client` StorageClass |
| `vpa-nfs-client-provisioner.yaml` | VerticalPodAutoscaler | VPA in Auto mode for the NFS provisioner (10m-250m CPU, 16Mi-256Mi memory) |

## Configuration

- **NFS Server**: `<internal-ip>` (TrueNAS on storage VLAN 40)
- **NFS Path**: `/mnt/tank/kubernetes`
- **StorageClass**: `nfs-client` (default, `archiveOnDelete: true`, `Retain` reclaim policy)
- **Mount Options**: NFSv4.1, hard mount, interruptible
- **Image**: `${IMAGE_NFS_PROVISIONER}` (substituted via Flux postBuild from SSOT)

## Storage Architecture

The cluster uses these storage backends:

| StorageClass | Provider | Backend | Use Case |
|-------------|----------|---------|----------|
| `nfs-client` (default) | nfs-subdir-external-provisioner | TrueNAS NFS `/mnt/tank/kubernetes` | General storage, configs, media, logs |
| `truenas-iscsi` | csi.truenas.io | TrueNAS iSCSI | PostgreSQL and stateful workloads requiring block storage (fsync semantics) |
| `truenas-nfs` | csi.truenas.io | TrueNAS NFS | RWX volumes provisioned through the official driver |
| `iscsi-csi` (legacy) | org.democratic-csi.iscsi | TrueNAS iSCSI | Decommissioned, being removed after migration cleanup |

NFS is unsuitable for PostgreSQL because it breaks fsync semantics. All database workloads use the `truenas-iscsi` StorageClass provisioned by the official TrueNAS CSI driver (`csi.truenas.io`), defined in `infrastructure/truenas-csi/`. The legacy `iscsi-csi` class (`org.democratic-csi.iscsi`) is being decommissioned now that data has migrated, since TrueNAS 26 removes the REST API the democratic-csi driver depended on.
