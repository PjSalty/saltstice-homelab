# prometheus/base/rules

PrometheusRule custom resources defining alert rules and recording rules. These are consumed by the Prometheus Operator deployed via kube-prometheus-stack.

## Files

| File | Description |
|------|-------------|
| `kustomization.yaml` | Lists all rule files: `infrastructure-alerts.yaml`, `trivy-security-alerts.yaml`, `slo-alerts.yaml`. |
| `infrastructure-alerts.yaml` | Infrastructure monitoring alerts covering certificates, disk space, backups, critical services, automation health, infrastructure VMs, and external service health. |
| `trivy-security-alerts.yaml` | Container image vulnerability alerts from the Trivy Operator, including scan health and compliance checks. |
| `slo-alerts.yaml` | Service Level Objective definitions with recording rules for SLI calculations, SLO breach alerts, and error budget tracking. |

## Infrastructure Alerts (`infrastructure-alerts.yaml`)

### Alert Groups

| Group | Interval | Alerts |
|-------|----------|--------|
| `certificates` | 1h | `CertificateExpiringSoon` (warning, <7 days), `CertificateExpiryCritical` (critical, <24h), `CertificateNotReady` (warning, 30m not-ready) |
| `disk-space` | 5m | `NodeDiskSpaceLow` (warning, <20%), `NodeDiskSpaceCritical` (critical, <10%), `PVCSpaceLow` (warning, <15%) |
| `backups` | 30m | `VeleroBackupFailed` (warning, failures in 24h), `VeleroBackupMissing` (warning, no success in 24h), `NFSExportUnavailable` (critical, blackbox probe fail) |
| `critical-services` | 1m | `FluxReconciliationFailing` (warning, 30m), `FluxSuspended` (info, 4h), `HelmReleaseNotReady` (warning, 30m) |
| `automation-health` | 5m | `CronJobFailed` (warning, Trivy/license/version/vm-update jobs), `CronJobNotScheduled` (warning, 48h no schedule) |
| `infrastructure-vms` | 1m | `CIRunnerNodeDown` (critical, <internal-ip> unreachable 5m) |

## Trivy Security Alerts (`trivy-security-alerts.yaml`)

### Alert Groups

| Group | Interval | Alerts |
|-------|----------|--------|
| `trivy-vulnerabilities` | 15m | `TrivyCriticalVulnerabilityDetected` (warning, >5 critical CVEs per image, 4h), `TrivyHighVulnerabilityDetected` (warning, >5 high CVEs, 4h), `TrivyExcessiveVulnerabilities` (warning, >100 total per image, 24h) |
| `trivy-operator-health` | 5m | `TrivyOperatorDown` (warning, 15m), `TrivyNoRecentScans` (warning, no scans in 24h), `TrivyScanJobFailed` (warning, failures in 1h) |
| `trivy-compliance` | 30m | `TrivyUnscannedImages` (info, >5 unscanned images, 6h), `TrivyConfigAuditFailure` (warning, critical config findings) |

## SLO Alerts (`slo-alerts.yaml`)

### Recording Rules (`sli-recording-rules`)

| Metric | Description |
|--------|-------------|
| `sli:traefik:availability:rate5m` | Traefik non-5xx request ratio over 5m |
| `sli:traefik:latency_p95:5m` | Traefik p95 latency over 5m |
| `sli:traefik:latency_p99:5m` | Traefik p99 latency over 5m |
| `sli:kubernetes_api:availability:rate5m` | Kubernetes API non-5xx request ratio over 5m |
| `sli:service:availability:rate5m` | Per-service availability from blackbox probes |

### SLO Targets

| Service | SLO | Alert |
|---------|-----|-------|
| Traefik Ingress | 99.9% availability | `TraefikSLOAvailabilityBreach` (warning) |
| Traefik Ingress | p95 < 500ms | `TraefikSLOLatencyBreach` (warning) |
| Kubernetes API | 99.99% availability | `KubernetesAPISLOBreach` (critical) |
| GitLab | 99.5% availability | `GitLabSLOBreach` (warning) |
| Harbor | 99.5% availability | `HarborSLOBreach` (warning) |
| Authentik | 99.5% availability | `AuthentikSLOBreach` (warning) |
| NFS Storage | 99.9% availability | `NFSSLOBreach` (critical) |
| SeaweedFS | 99.9% availability | `SeaweedFSSLOBreach` (warning) |

### Error Budget

| Metric / Alert | Description |
|----------------|-------------|
| `error_budget:traefik:remaining` | Tracks remaining monthly error budget (99.9% SLO = ~43 min/month of downtime allowed) |
| `TraefikErrorBudgetLow` | Warning when <25% budget remains |
| `TraefikErrorBudgetExhausted` | Critical when budget is fully consumed |
