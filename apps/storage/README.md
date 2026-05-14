# Storage

S3-compatible object storage for the homelab, powered by SeaweedFS. Provides bucket storage for GitLab Runner cache, Velero backups, AMP game server backups, and general object storage.

## Namespace

`storage`

## Subdirectories

### SeaweedFS/

SeaweedFS all-in-one deployment. See `seaweedfs/base/README.md` for full documentation including:
- Component architecture (Master, Volume, Filer, S3)
- Service URLs (internal and external)
- Pre-configured buckets
- Required secrets and credential generation
- AMP backup configuration
- Storage and monitoring details

## Directory Structure

```
seaweedfs/
  base/
    README.md                        - Detailed SeaweedFS documentation
    kustomization.yaml               - Kustomize manifest for all SeaweedFS resources
    namespace.yaml                   - Namespace with Goldilocks enabled
    deployment.yaml                  - SeaweedFS all-in-one Deployment (v4.07)
    service.yaml                     - Services for S3 (8333), Filer (8888), Master (9333), Metrics (9327)
    pvc.yaml                         - 200Gi NFS PVC for object data
    ingress.yaml                     - Traefik IngressRoutes for S3 API and Filer UI
    bucket-init-job.yaml             - Job creating required S3 buckets on startup
    servicemonitor.yaml              - Prometheus ServiceMonitor (30s interval)
    networkpolicy.yaml               - CiliumNetworkPolicy with fine-grained access control
    backup-cronjob.yaml              - Daily NFS backup via minio/mc mirror (3 AM)
    autoscaling/
      kustomization.yaml             - Lists VPA resource
      vpa.yaml                       - VPA in Auto mode (100m-2 CPU, 256Mi-4Gi memory)
```

## Services

| Service | Internal URL | External URL |
|---------|-------------|-------------|
| S3 API | `seaweedfs-s3.storage.svc:8333` | `https://s3.example.com` |
| Filer UI | `seaweedfs-filer.storage.svc:8888` | `https://seaweedfs.example.com` |
| Master | `seaweedfs-master.storage.svc:9333` | N/A |
| Metrics | `seaweedfs-metrics.storage.svc:9327` | N/A |

## Network Policy

CiliumNetworkPolicy controls access:
- **S3/Filer ingress**: Allowed from all cluster pods
- **Metrics ingress**: Allowed from monitoring namespace only
- **Master/Volume ingress**: Allowed from storage namespace only
- **Egress**: DNS to kube-system, intra-namespace, NFS to TrueNAS (<vlan-cidr>)

## Backup

Daily CronJob at 3 AM mirrors all S3 buckets to TrueNAS NFS (`/mnt/tank/backups/seaweedfs`) using `minio/mc mirror`.

## Dependencies

- TrueNAS NFS for persistent storage
- Wildcard TLS certificate (`wildcard-tls`)
- Authentik forward-auth for Filer UI access
- `seaweedfs-s3-config` Secret (from infrastructure/secrets repo)
