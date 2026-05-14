# observability

Prometheus, Grafana, Loki, Tempo, AlertManager. The targets are
infrastructure-wide: K8s, Proxmox, MikroTik, TrueNAS, Velero,
cert-manager, Falco, every app, every node, every database.

## Stack

| Component | Role |
|---|---|
| Prometheus | Metrics scraping, rule evaluation, remote-read for ad-hoc queries |
| AlertManager | Alert routing, deduplication, silencing |
| Grafana | Dashboards, the human-facing query interface |
| Loki | Logs |
| Tempo | Distributed traces (sparse use; mostly for the SaaS workload) |
| Promtail | Log shipping |
| node-exporter | Host metrics on every VM |
| kube-state-metrics | K8s object state |
| cAdvisor | Container metrics (bundled with kubelet) |
| Postgres-exporter / Redis-exporter | Database metrics, sidecar pattern |
| mktxp | MikroTik RouterOS metrics |
| Trivy operator | Vulnerability metrics |

Notification destination is Pushover for critical, Loki + Grafana
panel for everything else. Ntfy was the original target but produced
too much noise; Pushover at $5 one-time is the upgrade.

## Alert rule philosophy

Rules monitor *outcomes*, not just process liveness. Process-up is a
necessary but insufficient signal, the [Cilium silent-degradation
incident](https://example.com/incidents/2026-04-27-cilium-silent-degradation/)
came from an agent that passed its liveness probe while its datapath
was broken. Six rules now monitor drop rates, endpoint regeneration
failures, identity-cache size, BPF map pressure, outcome-based.

The infrastructure rule set covers:

- Certificate expiry (warn at 30 days, critical at 14)
- Backup freshness (Velero schedule completed within 26h)
- Node disk and memory pressure
- Pod CrashLoopBackOff
- NFS export availability
- CronJob failure
- DNS query rate / error rate (CoreDNS + AdGuard)
- HAProxy backend availability
- Trivy CVE counts (CRITICAL by namespace)
- Cilium six-rule degradation pack

SLO rules use multi-window error-budget burn for: Traefik availability
and latency, K8s API, GitLab, Harbor, Authentik. Burn-rate alerts
fire on fast burn (1h window) and slow burn (6h window) per Google's
SLO book methodology.

## Dashboards

Grafana dashboards by domain, Kubernetes overview, Trivy vulnerability
trend, security overview (RBAC + NetPol + PSA coverage), node-exporter,
Traefik, K8s audit. Custom dashboards for MikroTik (via mktxp), Cilium
identity cache, Velero schedule status.

Dashboards are JSON-defined and versioned in Git. Updates land via
ConfigMap reload in Grafana. No manual dashboard edits in the UI; that
discipline is the only way to keep dashboards reproducible.

## Logs

Loki backed by SeaweedFS S3 for chunks. Promtail DaemonSet on every
node. Per-namespace log retention via Loki rules: critical apps
(Authentik, Vaultwarden) keep 30 days; app logs default to 7 days;
debug-noisy namespaces (init jobs) keep 24 hours.

## What's not here

- Long-term metric retention. Prometheus has 15-day local retention;
 longer-term storage isn't wired (Thanos / Cortex would be the answer
 but adds operational complexity that hasn't paid for itself yet).
- APM. Tempo handles distributed traces for the SaaS workload, but
 most homelab apps don't emit OpenTelemetry. Acceptable.

## Where the configs live

Prometheus rules and ServiceMonitors live alongside the apps that
generate them (`apps/<app>/monitoring/`) when they're app-specific,
and under `infrastructure/monitoring/` when they're cluster-wide.
Grafana dashboards are in their own dashboards repo and synced via
ConfigMap.
