# Security

Security scanning and compliance tools for the homelab Kubernetes cluster. Contains Trivy vulnerability scanning and SBOM/license compliance management.

## Namespace

`security`

## Directory Structure

```
trivy/
  kustomization.yaml                    - Kustomize manifest for Trivy resources
  namespace.yaml                        - Namespace (PSA privileged for scan pods)
  trivy-operator.yaml                   - Trivy operator Deployment, ServiceAccount, RBAC, Service, ServiceMonitor
  trivy-alerts.yaml                     - PrometheusRule with vulnerability alerting rules
  pvc-reports.yaml                      - 10Gi NFS PVC for scan reports (30-day retention)
  scan-cronjob.yaml                     - Daily full image scan CronJob (2 AM)
  report-aggregator-cronjob.yaml        - Weekly vulnerability trend report (Monday 6 AM)
  crds/
    aquasecurity-crds.yaml              - Aqua Security CRDs for vulnerability reports
  autoscaling/
    kustomization.yaml                  - Lists VPA resource
    vpa.yaml                            - VPA in Auto mode (100m-2 CPU, 256Mi-2Gi memory)

sbom-manager/
  base/
    kustomization.yaml                  - Kustomize manifest for SBOM resources
    license-policy.yaml                 - ConfigMap defining allowed/disallowed licenses
    license-scan-cronjob.yaml           - Weekly license compliance scan (Sunday 4 AM)
```

## Trivy Operator

### Deployment

- **Image**: Managed via `${IMAGE_TRIVY_OPERATOR}` Flux variable
- **Replicas**: 1
- **Scanners enabled**: Vulnerability scanning only (SBOM, config audit, RBAC, infra assessment, exposed secrets, compliance all disabled to reduce load)
- **Excluded namespaces**: kube-system, kube-public, kube-node-lease, Flux-system, vpa, Goldilocks
- **Severity filter**: CRITICAL, HIGH, MEDIUM
- **Concurrent scan limit**: 3 jobs
- **Scan timeout**: 15 minutes per job

### RBAC

The `trivy-operator` ClusterRole has broad access including:
- Read access to all core, apps, batch, RBAC, and networking resources
- Full CRUD on Aqua Security CRDs (vulnerability reports, etc.)
- Full CRUD on secrets/ConfigMaps (for operator state)
- Create/delete on batch jobs (for scan execution)

### Monitoring

- **ServiceMonitor**: Scrapes metrics at port 8080, 60s interval
- **Prometheus alerts**: Defined in `trivy-alerts.yaml`

### Alert Rules

| Alert | Condition | Severity |
|-------|-----------|----------|
| `TrivyCriticalVulnerability` | Any critical vulnerability for 1h | critical |
| `TrivyHighVulnerabilityCount` | >10 high vulns per image for 4h | warning |
| `TrivyClusterVulnerabilityThreshold` | >50 critical+high cluster-wide for 6h | warning |
| `TrivyNewVulnerableImage` | New vulnerability count change | info |
| `TrivyOperatorDown` | Operator not running for 15m | warning |
| `TrivyScanJobsFailing` | >3 failed scan jobs in 1h | warning |

## Daily Vulnerability Scan

The `trivy-full-scan` CronJob runs at 2 AM daily:
1. Init container collects all unique images via kubectl
2. Main container scans each image with Trivy
3. JSON reports saved to `/reports/YYYY-MM-DD/` with per-image results
4. Daily summary JSON with aggregate counts
5. Reports older than 30 days automatically cleaned

## Weekly Report Aggregator

The `trivy-weekly-report` CronJob runs Monday at 6 AM:
- Aggregates daily summaries into weekly trend data
- Calculates averages for critical/high/medium per day
- Generates JSON with trend arrays for visualization

## License Compliance (SBOM Manager)

### License Policy

Defined in `license-policy.yaml` ConfigMap:
- **Allowed**: MIT, Apache-2.0, BSD-2/3-Clause, ISC, MPL-2.0, PostgreSQL, Python-2.0, etc.
- **Disallowed (review required)**: GPL-2.0/3.0, LGPL, AGPL (copyleft licenses requiring source disclosure)

### License Scan CronJob

Runs weekly (Sunday 4 AM):
1. Init container lists all pod images via kubectl
2. Trivy scans each image for license data
3. Reports any images containing disallowed (copyleft) licenses
4. Exits with code 1 if violations found

## Storage

- **Reports PVC**: 10Gi on `nfs-client` (ReadWriteMany), stores vulnerability scan reports

## Autoscaling

- **VPA**: Auto mode for Trivy-operator (100m-2 CPU, 256Mi-2Gi memory)

## Pod Security

Namespace uses `privileged` PSA enforcement because Trivy operator scan pods require elevated access for image scanning. Goldilocks is enabled.
