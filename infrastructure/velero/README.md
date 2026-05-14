# Velero

Kubernetes backup with Velero. S3 backend is in-cluster SeaweedFS
(`seaweedfs-s3.storage.svc:8333`, bucket `velero`). Kopia uploader.
Node agent DaemonSet for filesystem backups.

## Layout

```
infrastructure/controllers/velero/
├── namespace.yaml
├── helmrelease.yaml          , chart version from image-versions ConfigMap
├── kustomization.yaml
└── autoscaling/
    └── vpa.yaml

infrastructure/configs/velero/
└── schedules.yaml            , daily-full + hourly-stateful schedules
```

## Why this shape

- **Kopia, not Restic.** Restic is removed in Velero v1.17. New deployments
 go straight to Kopia.
- **`velero-plugin-for-aws` v1.14.0** is required for any S3-compatible
 backend (SeaweedFS, MinIO, B2 limited). Pinned by digest.
- **`s3ForcePathStyle: true`** is mandatory, SeaweedFS doesn't support
 virtual-host-style URLs.
- **CRDs managed by Flux**, not the chart's CRD upgrade hooks. Chart
 hooks copy a musl-linked `sh` into the distroless Velero container,
 which fails. `upgradeCRDs: false` + `cleanUpCRDs: false` lets Flux
 reconcile CRDs via `crds: CreateReplace`.
- **`deployNodeAgent: true`** runs a DaemonSet on every node to perform
 Kopia file-system backups for any PVC marked
 `defaultVolumesToFsBackup: true`.

## Backup schedules

| Schedule | Cron | TTL | Scope |
|---|---|---|---|
| `daily-full` | `0 2 * * *` (UTC) | 72h | full namespace bundles for `authentik`, `vaultwarden`, `docmost`, `semaphore` |
| `hourly-stateful` | `15 * * * *` | 48h | PVC + Secret + ConfigMap snapshots for `authentik`, `vaultwarden` |

`storage` and `monitoring` namespaces are excluded, reproducible from
Git, no value to back up. `media` is excluded, NFS-backed, NAS snapshots
provide its recovery tier. Databases have their own logical-dump CronJobs
with 7-day retention; Velero is for the rest.

## Three independent recovery tiers

1. **Velero + SeaweedFS**, namespace state, CRDs, PVC contents via
 Kopia. Restores via `velero restore create`.
2. **Logical database dumps** to a separate SeaweedFS bucket on per-DB
 CronJobs. PITR-capable.
3. **NAS snapshots on the underlying ZFS pool** under SeaweedFS, the
 metabacker. If Velero state is corrupted, restore the SeaweedFS
 volume to a known-good snapshot, then `velero backup get` works
 again.

Off-site is the gap. ZFS replication to an external bucket is wired
but disabled until i find an off-site host i trust enough.

## Restore drill

Quarterly restore against a scratch namespace:

```bash
kubectl create ns vaultwarden-drill
velero restore create \
  --from-backup hourly-stateful-<timestamp> \
  --namespace-mappings vaultwarden:vaultwarden-drill
```

Verify Vaultwarden serves Vault, then tear it down. Catches at least
one bug a year.

## Required alerts

- `VeleroBackupFailed`, last scheduled backup is in `Failed` phase
- `VeleroBackupStale`, last successful backup older than 26h
- `SeaweedFSDown`, Velero's storage backend unreachable

## ADR

[`docs/adrs/0005-velero-seaweedfs-in-cluster-backup.md`](../../docs/adrs/0005-velero-seaweedfs-in-cluster-backup.md)
