# storage

## Tiers

| Use | Tier | Why |
|---|---|---|
| Databases (Postgres, Mongo, SQLite) | iSCSI block (RWO) | fsync semantics |
| Shared-read media | NFS (RWX) | read fan-out |
| Backup target | SeaweedFS S3 | in-cluster, no egress |
| Logs / metrics | local + S3 | hot on PVC, cold on S3 |

## NAS

TrueNAS SCALE on bare metal. ZFS pools on dedicated disks, separate
from the Proxmox boot pool. Datasets tuned per workload (LZ4
compression, atime off, record sizes matched: 1MB media, 128KB
database iSCSI extents).

## CSI

`truenas-csi` (provisioner `csi.truenas.io`), the official iX driver,
talking to TrueNAS over WebSocket-native JSON-RPC at
`wss://truenas.example.com/api/current`. Two storage classes:

- `truenas-iscsi`, RWO block, dynamic provisioning of iSCSI extents
- `truenas-nfs`, RWX file, dynamic provisioning of NFS shares

The legacy `iscsi-csi` class (provisioner `org.democratic-csi.iscsi`,
legacy REST `/api/v2.0`) is being decommissioned. TrueNAS 26 removes
the REST API and democratic-csi never added WebSocket support, so the
data moved to `truenas-csi`. Data's already migrated.

The driver runs in the `truenas-csi` namespace:

```bash
kubectl get pods -n truenas-csi
```

## Why iSCSI for databases

NFS allows `fsync()` to return success before the server commits to
stable storage. That's a corruption bug waiting for a power loss or
NFS server crash. ISCSI is block storage; the kernel handles fsync the
same way as a local disk, ZFS underneath provides the actual durability.
PostgreSQL docs are unambiguous on this.

ADR: `docs/adrs/0002-iscsi-over-nfs-for-postgres.md` (when published).

## SeaweedFS for in-cluster S3

Velero needs an S3 target. Cloud S3 = recurring egress + external
dependency. SeaweedFS S3 gateway runs in-cluster, backs to TrueNAS
iSCSI, ZFS provides the durability tier.

Endpoint: `seaweedfs-s3.storage.svc:8333`. Bucket: `velero`. Same
gateway also fronts `pg-archives`, `registry-mirror`, and a couple
of ad-hoc buckets.

## Backup tiers

1. Velero + SeaweedFS via Kopia. Daily full namespace, hourly
 stateful subset. 14-day retention.
2. Per-database `pg_dump` to its own bucket. PITR-capable.
3. ZFS snapshots on the underlying pool. Recovers from corrupted
 Velero state.

Off-site replication is wired but disabled.

## Quarterly drill

```bash
kubectl create ns vaultwarden-drill
velero restore create \
  --from-backup hourly-stateful-<timestamp> \
  --namespace-mappings vaultwarden:vaultwarden-drill
```

Verify, tear down. Catches a real bug about once a year.
