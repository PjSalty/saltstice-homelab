# Democratic-CSI (iSCSI)

> **DEPRECATED:** replaced by the official WebSocket-native truenas-csi driver (`csi.truenas.io`). Kept here for history while the migration cleanup completes.

iSCSI CSI driver for TrueNAS, providing block storage for stateful workloads that require proper fsync semantics (primarily PostgreSQL). Deployed as a HelmRelease with a standalone StorageClass.

Deployed by the `democratic-csi` Flux Kustomization from `clusters/homelab/infrastructure-kustomizations.yaml`, which depends on `nfs-storage` and uses SOPS decryption for TrueNAS credentials.

## Directory Structure

```
democratic-csi/
  kustomization.yaml        # Points to base/
  base/
    kustomization.yaml      # Aggregates all resources
    namespace.yaml          # Namespace with privileged PSA (host iSCSI access)
    helmrepository.yaml     # democratic-csi Helm chart repository
    storageclass.yaml       # iscsi-csi StorageClass (managed outside Helm)
    helmrelease/
      democratic-csi-iscsi.yaml  # HelmRelease for the iSCSI CSI driver
    secrets/
      truenas-credentials.yaml   # SOPS-encrypted TrueNAS API credentials
    autoscaling/
      vpa.yaml              # VPA in Auto mode for CSI components
    pdb/
      pdb.yaml              # PodDisruptionBudget for controller
```

## Key Design Decisions

### Standalone StorageClass

The `iscsi-csi` StorageClass is defined in `storageclass.yaml` outside of the Helm chart because StorageClass fields are immutable after creation. Helm cannot update immutable fields on chart upgrades, so the HelmRelease has `storageClasses: []` and the StorageClass is managed as a standalone Kustomize resource.

### When to Use iSCSI vs NFS

| Use Case | StorageClass | Reason |
|----------|-------------|--------|
| PostgreSQL | `iscsi-csi` | Block storage required for fsync/fdatasync semantics |
| Redis | `iscsi-csi` | Block storage for AOF persistence |
| General config/data | `nfs-client` | Shared file storage, no fsync requirement |
| Media files | `nfs-client` | Large files, concurrent read access |

### TrueNAS Integration

- **API**: TrueNAS REST API v2.0 on `<internal-ip>` (storage VLAN 40)
- **Protocol**: iSCSI with CHAP authentication
- **Provisioner**: `org.democratic-csi.iscsi`
- **Reclaim Policy**: Retain
- **Volume Expansion**: Enabled

## Kustomization

```yaml
resources:
  - base
```
