# How-to: in-cluster Velero with SeaweedFS S3

End-to-end Kubernetes backup that stays inside your cluster. No
cloud egress costs, no external dependencies. SeaweedFS is the S3
gateway; ZFS underneath provides durability.

## 1. Deploy SeaweedFS

A minimal HelmRelease (chart from `seaweedfs/seaweedfs`):

```yaml
apiVersion: helm.toolkit.fluxcd.io/v2
kind: HelmRelease
metadata:
  name: seaweedfs
  namespace: storage
spec:
  interval: 30m
  chart:
    spec:
      chart: seaweedfs
      version: "4.x"
      sourceRef:
        kind: HelmRepository
        name: seaweedfs
        namespace: flux-system
  values:
    master:
      replicas: 1
    volume:
      replicas: 1
      data:
        type: persistentVolumeClaim
        size: 500Gi
        storageClass: truenas-iscsi
    s3:
      enabled: true
      replicas: 1
    filer:
      enabled: true
```

The volume server's PVC is RWO iSCSI from `truenas-csi`
(provisioner `csi.truenas.io`). ZFS on the TrueNAS side provides
snapshots and durability.

## 2. Create the bucket and credentials

```bash
# Wait for SeaweedFS to be Ready
kubectl wait -n storage --for=condition=Ready pod -l app=seaweedfs --timeout=300s

# Create the velero bucket
kubectl exec -n storage svc/seaweedfs-master -- \
  weed shell <<EOF
s3.bucket.create -name=velero
EOF

# Generate access keys
kubectl exec -n storage svc/seaweedfs-master -- \
  weed shell <<EOF
s3.configure -access_key=velero-key -secret_key=$(openssl rand -hex 32) \
  -buckets=velero -user=velero -actions=Read,Write,List,Tagging,Admin -apply
EOF
```

Pull the access/secret keys you set and stash them as a K8s Secret
that Velero will read:

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: velero-s3-credentials
  namespace: velero
type: Opaque
stringData:
  cloud: |
    [default]
    aws_access_key_id = velero-key
    aws_secret_access_key = <the-secret-you-set>
```

Encrypt that Secret with SOPS before committing.

## 3. Install Velero

```yaml
apiVersion: helm.toolkit.fluxcd.io/v2
kind: HelmRelease
metadata:
  name: velero
  namespace: velero
spec:
  interval: 30m
  chart:
    spec:
      chart: velero
      version: "8.x"
      sourceRef:
        kind: HelmRepository
        name: vmware-tanzu
        namespace: flux-system
  install:
    crds: CreateReplace
  upgrade:
    cleanupOnFail: true
    crds: CreateReplace
  values:
    initContainers:
      - name: velero-plugin-for-aws
        image: velero/velero-plugin-for-aws:v1.14.0
        volumeMounts:
          - mountPath: /target
            name: plugins
    configuration:
      backupStorageLocation:
        - name: default
          provider: aws
          bucket: velero
          config:
            region: us-east-1
            s3ForcePathStyle: "true"
            s3Url: http://seaweedfs-s3.storage.svc:8333
      uploaderType: kopia
      defaultVolumesToFsBackup: true
    credentials:
      useSecret: true
      existingSecret: velero-s3-credentials
    deployNodeAgent: true
    upgradeCRDs: false
    cleanUpCRDs: false
```

Critical bits:

- `velero-plugin-for-aws` is required for any S3-compatible backend.
 Pin a version, don't track `latest`.
- `s3ForcePathStyle: true` is mandatory, SeaweedFS doesn't support
 virtual-host-style URLs.
- `uploaderType: kopia`, never `restic` (Restic is removed in v1.17+).
- `upgradeCRDs: false` and `cleanUpCRDs: false` because the chart's
 built-in CRD upgrade hooks copy a musl-linked `sh` into the
 distroless Velero container and explode. Flux handles CRDs via
 `crds: CreateReplace` instead.

## 4. Add schedules

```yaml
apiVersion: velero.io/v1
kind: Schedule
metadata:
  name: daily-full
  namespace: velero
spec:
  schedule: "0 2 * * *"
  template:
    ttl: 72h
    includedNamespaces:
      - authentik
      - vaultwarden
      - docmost
    storageLocation: default
    defaultVolumesToFsBackup: true
---
apiVersion: velero.io/v1
kind: Schedule
metadata:
  name: hourly-stateful
  namespace: velero
spec:
  schedule: "15 * * * *"
  template:
    ttl: 48h
    includedNamespaces: [authentik, vaultwarden]
    includedResources:
      - persistentvolumeclaims
      - persistentvolumes
      - secrets
      - configmaps
      - deployments
      - statefulsets
      - services
    storageLocation: default
    defaultVolumesToFsBackup: true
```

## 5. Verify

```bash
velero backup-location get
# default     Available

velero backup get
# (after the first scheduled backup)
# NAME                       STATUS      CREATED   ...
# daily-full-20260507        Completed   ...
```

Browse the SeaweedFS bucket directly:

```bash
kubectl exec -n storage svc/seaweedfs-master -- \
  weed shell <<EOF
s3.bucket.list
EOF
```

## 6. Run a restore drill

Once a quarter, do a real restore against a scratch namespace:

```bash
kubectl create ns vaultwarden-drill
velero restore create \
  --from-backup hourly-stateful-<timestamp> \
  --namespace-mappings vaultwarden:vaultwarden-drill
```

Verify the restored namespace works (Postgres connects, the app
serves traffic). Tear it down. The drill catches at least one bug a
year, usually a missing CRD or a hardcoded namespace reference in a
secret.

## What you don't get

Off-site geographic redundancy. A house fire takes out cluster, NAS,
and backup. Add `rclone` to a B2 bucket on a CronJob if that matters.

Native S3 IAM. SeaweedFS S3 has only access-key auth. Sufficient for
this use case; not equivalent to AWS IAM.

A pretty backup dashboard. `velero` CLI plus `kubectl` is the entire
interface. Acceptable for a one-operator setup.
