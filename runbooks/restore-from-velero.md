# Runbook: restore from Velero

Generic restore procedure. Works for full-namespace restore, single
PVC, or cross-namespace clone. Run quarterly as a drill against a
scratch namespace to keep the muscle current.

## Pre-flight

```bash
# Velero CLI matches server version
velero version

# Backup location is healthy
velero backup-location get
# default     Available

# List backups
velero backup get
# Pick the one you want. Note the exact name.
```

## Full namespace restore (production)

```bash
BACKUP=daily-full-20260507  # the backup name from `velero backup get`
NAMESPACE=docmost

# Optional: scale the existing app to zero so there are no writers
kubectl scale -n "$NAMESPACE" deployment --all --replicas=0

# Restore
velero restore create restore-$NAMESPACE-$(date +%s) \
  --from-backup "$BACKUP" \
  --include-namespaces "$NAMESPACE" \
  --wait

# Bring the app back up
kubectl scale -n "$NAMESPACE" deployment --all --replicas=1
```

## Cross-namespace restore (drill or migration)

```bash
BACKUP=hourly-stateful-20260507143000
SOURCE_NS=vaultwarden
DEST_NS=vaultwarden-drill

kubectl create ns "$DEST_NS"

velero restore create drill-$(date +%s) \
  --from-backup "$BACKUP" \
  --namespace-mappings "$SOURCE_NS:$DEST_NS" \
  --wait

# Verify
kubectl get pods,pvc,svc -n "$DEST_NS"

# Tear down when done
kubectl delete ns "$DEST_NS"
```

## Single PVC restore

When only one PVC is corrupted and the rest of the namespace is fine.

```bash
BACKUP=hourly-stateful-20260507143000
NAMESPACE=docmost
PVC=docmost-postgres-data

# Stop the consumer
kubectl scale -n "$NAMESPACE" statefulset docmost-postgres --replicas=0

# Delete the PVC (PV stays as Released because reclaimPolicy is Retain)
kubectl delete pvc "$PVC" -n "$NAMESPACE"

# Restore just that PVC
velero restore create pvc-restore-$(date +%s) \
  --from-backup "$BACKUP" \
  --include-namespaces "$NAMESPACE" \
  --include-resources persistentvolumeclaims,persistentvolumes \
  --selector "app=docmost-postgres" \
  --wait

# Restart the consumer
kubectl scale -n "$NAMESPACE" statefulset docmost-postgres --replicas=1
```

## Verify

```bash
# Restore status
velero restore get
# Look for STATUS=Completed and ERRORS=0, WARNINGS=<expected>

# Detailed log if something fails
velero restore logs <restore-name>

# Resource sanity
kubectl get all,pvc -n "$NAMESPACE"

# App-specific health check (database connects, app serves traffic)
```

## Common gotchas

- **`creationPolicy: Merge` ExternalSecrets**: target Secret must
 already exist before ESO can merge into it. Restore the Secret
 first, then let ESO refresh.
- **CRDs missing**: if you restore into a fresh cluster and the
 namespace had CRD-backed resources (e.g., custom Cilium policies),
 the CRDs need to exist first. Velero restores CRDs by default; if
 you scoped the restore narrowly, you may need to re-include them.
- **PVC StorageClass must exist**: you can't restore an iSCSI PVC
 into a cluster that doesn't have democratic-CSI installed. Same
 for NFS.
- **Hooks**: pre-/post-restore hooks defined on the original Backup
 spec run on restore unless you `--exclude-hooks`. Check what
 hooks the backup carried.

## Related

- [ADR: Velero with SeaweedFS](../docs/adrs/velero-with-seaweedfs.md)
- [How-to: install Velero with SeaweedFS S3](../how-to/velero-with-seaweedfs-s3.md)
