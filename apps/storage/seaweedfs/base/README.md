# SeaweedFS Object Storage

S3-compatible object storage for the homelab, replacing MinIO (which stopped binary releases in Oct 2025).

## Components

- **Master**: Volume management (port 9333)
- **Volume**: Data storage (port 8080)
- **Filer**: File system abstraction (port 8888)
- **S3**: S3 API with embedded IAM (port 8333)

## URLs

| Service | Internal | External |
|---------|----------|----------|
| S3 API | `seaweedfs-s3.storage.svc:8333` | `https://s3.example.com` |
| Filer UI | `seaweedfs-filer.storage.svc:8888` | `https://seaweedfs.example.com` |
| Metrics | `seaweedfs-metrics.storage.svc:9327` | N/A |

## Pre-configured Buckets

The bucket-init-job creates these buckets automatically:

- `gitlab-runner-cache` - GitLab CI/CD cache
- `amp-backups` - AMP game server backups
- `velero` - Kubernetes cluster backups
- `backups` - General purpose backups

## Required Secrets

Secrets must be created in the `infrastructure/secrets` repository.

### 1. SeaweedFS S3 Configuration

**File**: `kubernetes/storage/seaweedfs-s3-config.yaml`

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: seaweedfs-s3-config
  namespace: storage
type: Opaque
stringData:
  s3.json: |
    {
      "identities": [
        {
          "name": "admin",
          "credentials": [
            {
              "accessKey": "<GENERATE_ACCESS_KEY>",
              "secretKey": "<GENERATE_SECRET_KEY_MIN_40_CHARS>"
            }
          ],
          "actions": ["Admin", "Read", "Write", "List", "Tagging"]
        },
        {
          "name": "gitlab-runner",
          "credentials": [
            {
              "accessKey": "<GENERATE_ACCESS_KEY>",
              "secretKey": "<GENERATE_SECRET_KEY_MIN_40_CHARS>"
            }
          ],
          "actions": ["Read", "Write", "List"]
        },
        {
          "name": "amp-backup",
          "credentials": [
            {
              "accessKey": "<GENERATE_ACCESS_KEY>",
              "secretKey": "<GENERATE_SECRET_KEY_MIN_40_CHARS>"
            }
          ],
          "actions": ["Read", "Write", "List"]
        },
        {
          "name": "velero",
          "credentials": [
            {
              "accessKey": "<GENERATE_ACCESS_KEY>",
              "secretKey": "<GENERATE_SECRET_KEY_MIN_40_CHARS>"
            }
          ],
          "actions": ["Read", "Write", "List", "Tagging"]
        }
      ]
    }
```

### 2. GitLab Runner S3 Credentials

**File**: `kubernetes/gitlab-runner/seaweedfs-s3-credentials.yaml`

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: seaweedfs-s3-credentials
  namespace: gitlab-runner
type: Opaque
stringData:
  access-key: <SAME_AS_GITLAB_RUNNER_ACCESS_KEY>
  secret-key: <SAME_AS_GITLAB_RUNNER_SECRET_KEY>
```

## Generating Credentials

```bash
# Generate access key (20 chars)
openssl rand -hex 10

# Generate secret key (40 chars minimum)
openssl rand -hex 20
```

## AMP Backup Configuration

Configure AMP to use SeaweedFS for backups:

- **S3 Endpoint**: `https://s3.example.com` (external) or `http://seaweedfs-s3.storage.svc:8333` (internal)
- **Bucket**: `amp-backups`
- **Region**: `me-east-1` (any value works, SeaweedFS ignores it)
- **Access Key**: From `amp-backup` identity in s3.json
- **Secret Key**: From `amp-backup` identity in s3.json

## Storage

Data is stored on TrueNAS via NFS:
- StorageClass: `nfs-client`
- PVC Size: 200Gi
- Mount: `/data` in container

## Monitoring

Prometheus ServiceMonitor is included. Metrics available at:
- Endpoint: `seaweedfs-metrics.storage.svc:9327`
- Path: `/metrics`
