# ADR: Velero + SeaweedFS for in-cluster Kubernetes backup

**Status:** Accepted

## Context

Need a Kubernetes backup story: PVCs, namespace state, CRDs, the
whole thing. Industry default is Velero with an S3-compatible backend.

Budget for the homelab: zero recurring cloud spend. AWS S3 plus
egress would be real money even at homelab scale, and the cloud
"backup tier" pricing has a habit of growing teeth.

## Decision

Velero v1.17 with the Kopia uploader, backed by an in-cluster
SeaweedFS S3 gateway. SeaweedFS volumes persist to TrueNAS over iSCSI;
ZFS handles actual durability.

## Reasoning

S3 is a protocol, not a vendor. Velero's only durable backend
requirement is "an S3-compatible API." MinIO, SeaweedFS, Garage,
the cloud S3s, all qualify. The protocol constraint doesn't force a
vendor.

Kopia, not Restic. Velero v1.17 dropped Restic. New deployments
should use Kopia from day one.

SeaweedFS over MinIO. Both are S3-compatible. Picked SeaweedFS
because the volume-server architecture is simpler than MinIO's
distributed-mode requirements (4+ nodes for any erasure coding).
SeaweedFS runs comfortably on one node with replication if i want it.
Lower memory footprint at idle. The S3 gateway is a separate process
from the volume server, so they scale or restart independently.

Cost at this scale: zero recurring. Storage is iSCSI to TrueNAS,
electricity is already paid. The only cost is disk space on the NAS,
which is overprovisioned anyway.

## What i gave up

Off-site geographic redundancy. A house fire takes out the cluster
AND the NAS AND the backups. The mitigation is a periodic
`rclone copy` from a SeaweedFS bucket to Backblaze B2 (cheap), but
it's wired and disabled. This is the one real gap.

Restic compatibility. Pre-Kopia Restic backups can't be restored.
Never had Restic backups, so this is fine.

Operator UX. Velero CLI plus `kubectl` is the entire interface. No
pretty dashboard.

## Schedule and retention

Daily full backups at 02:00 UTC, 72-hour retention. Hourly stateful
subset (Authentik, Vaultwarden), 48-hour retention. Pre-deploy hook
on Flux Kustomizations triggers a one-shot backup when a HelmRelease
is about to upgrade, a clean restore point per change.

## What backs up the backup

Three independent recovery tiers because one isn't enough:

1. Velero + SeaweedFS via Kopia.
2. `pg_dump` per database to a separate SeaweedFS bucket.
3. ZFS snapshots on the underlying TrueNAS pool, the metabacker.
 Restore SeaweedFS volume to a known-good ZFS snapshot if Velero
 state itself is corrupted.

## When i would reconsider

- Off-site becomes urgent → wire the rclone path, no architectural
 change.
- Cluster scale grows past one SeaweedFS node → MinIO distributed.
- Move to managed K8s → vendor backup tiers (EKS Backup, GKE Backup)
 are usually fine.
