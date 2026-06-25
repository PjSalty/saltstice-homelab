# ADR: iSCSI block storage for databases, not NFS

**Status:** Accepted

_Update, 2026-06: the CSI driver has since moved from democratic-csi to the
official truenas-csi (`csi.truenas.io`, WebSocket-native), because TrueNAS 26
removes the REST API democratic-csi depends on. The decision below, iSCSI block
for databases and NFS for shared, is unchanged. Only the driver changed._

## Context

Postgres, Mongo, anything with WAL. The CSI driver
(`democratic-csi`) supports both NFS and iSCSI backends from the same
TrueNAS host. NFS is the default in most homelab tutorials.
simpler, RWX, single share for everything.

## Decision

iSCSI block storage for every database PVC. NFS for shared-read
content only.

## Reasoning

NFS doesn't guarantee POSIX fsync semantics. The protocol allows the
client to acknowledge `fsync()` before the server has committed to
stable storage. With the `sync` mount option, NFSv3 forces a
server-side commit on close, per file, not per block. Postgres
expects per-block durability.

Practical consequence: a power loss, network partition, or NFS server
crash during a busy write can leave Postgres with corrupted WAL. The
recovery path is "your last good backup", not "automatic crash
recovery from WAL", because the WAL itself is the corrupted file.

iSCSI presents a block device. The Linux block layer handles `fsync()`
the same way as a local disk. ZFS on the TrueNAS side handles the
durability with its own transaction-group commits. Postgres `fsync()`
calls become real durable writes.

The PostgreSQL community position is decades old and unambiguous. The
official docs say not to use NFS unless the NFS server explicitly
supports the full POSIX fsync semantics, which most don't.

## Trade-offs

| | NFS | iSCSI |
|---|---|---|
| Setup complexity | low | medium (open-iSCSI, optional multipath) |
| Multi-node mount | RWX | RWO |
| Backup | rsync the share | volume snapshot, pg_basebackup |
| Resize | server-side, trivial | needs `resize2fs` in-guest |
| Postgres durability | broken | correct |
| Random write performance | adequate | better |

iSCSI is RWO. Postgres can't run as a multi-replica StatefulSet
across nodes sharing one volume, and shouldn't anyway. Postgres
replication is between distinct database instances each with their
own storage, not multiple processes against one filesystem. RWO is
the correct shape for Postgres.

## Consequence

Every database PVC uses the `iscsi-csi` StorageClass. Deployment
strategy is `Recreate` because RWO can't roll. Backups are CNPG WAL
archive to SeaweedFS plus periodic `pg_basebackup` to a different
bucket.

NFS is fine for everything else: media library, stateless app config,
Jellyfin transcode caches.

## When i would reconsider

Never, for Postgres. The semantics aren't going to change.
Same answer for Mongo with strong durability, Redis with persistence,
etcd, anything WAL-based.
