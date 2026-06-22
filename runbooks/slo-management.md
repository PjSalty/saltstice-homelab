# Service Level Objectives (SLOs)

SLOs for the critical homelab services.

## SLO Definitions

### Traefik Ingress

| SLI | Target | Severity |
|-----|--------|----------|
| Availability | 99.9% | Warning |
| Latency (p95) | < 500ms | Warning |
| Error Budget | > 25% remaining | Warning |

**Error Budget**: ~43 minutes/month of downtime allowed

### Kubernetes API

| SLI | Target | Severity |
|-----|--------|----------|
| Availability | 99.99% | Critical |

**Error Budget**: ~4.3 minutes/month of downtime allowed

### Infrastructure Services

| Service | Availability Target | Severity |
|---------|---------------------|----------|
| GitLab | 99.5% | Warning |
| Harbor | 99.5% | Warning |
| Authentik | 99.5% | Warning |

**Error Budget**: ~3.6 hours/month of downtime allowed per service

### Storage Services

| Service | Availability Target | Severity |
|---------|---------------------|----------|
| NFS Storage | 99.9% | Critical |
| SeaweedFS | 99.9% | Warning |

**Error Budget**: ~43 minutes/month of downtime allowed

## Alert Response

### SLO Breach (Warning)

1. Check service health: `kubectl get pods -n <namespace>`
2. Check recent changes: `flux get all -A | grep -v "True"`
3. Review metrics in Grafana
4. Consider rollback if recent deployment caused issues

### SLO Breach (Critical)

1. Immediate service health check
2. Check underlying infrastructure (nodes, storage)
3. Consider scaling resources
4. Page on-call if not self-resolving in 15 minutes

### Error Budget Low (< 25%)

1. Freeze non-critical deployments
2. Review reliability improvements
3. Schedule maintenance window for fixes
4. Document incident for post-mortem

### Error Budget Exhausted

1. Critical incident - all hands on deck
2. Rollback any recent changes
3. Focus on stability over new features
4. Create incident report

## Monitoring

### Grafana Dashboards

- **SLO Overview**: Shows all SLO status at a glance
- **Error Budget Tracker**: Tracks monthly error budget consumption

### Prometheus Queries

```promql
# Current Traefik availability
sli:traefik:availability:rate5m

# Current Traefik p95 latency
sli:traefik:latency_p95:5m

# Traefik error budget remaining
error_budget:traefik:remaining

# Kubernetes API availability
sli:kubernetes_api:availability:rate5m
```

## SLO Review Cadence

| Review Type | Frequency | Participants |
|-------------|-----------|--------------|
| Quick check | Daily | On-call |
| Trend review | Weekly | Team |
| SLO revision | Quarterly | All stakeholders |

## Adjusting SLOs

SLOs should be adjusted based on:

1. Historical performance data
2. User expectations
3. Infrastructure capabilities
4. Business requirements

To adjust an SLO:

1. Update `prometheus/base/rules/slo-alerts.yaml`
2. Update this documentation
3. Commit and let Flux reconcile
