# Service Restart Runbook

## Overview

How to restart services. They split by deployment method: VM-based (Ansible) or Kubernetes (FluxCD).

## Quick Reference

| Service | Type | Restart Command |
|---------|------|-----------------|
| AdGuard DNS | K8s | `kubectl rollout restart deployment/adguard-home -n adguard` |
| Traefik | K8s | `kubectl rollout restart deployment/traefik -n traefik` |
| Grafana | K8s | `kubectl rollout restart deployment/grafana -n monitoring` |
| Prometheus | K8s | `kubectl rollout restart statefulset/prometheus -n monitoring` |
| Authentik | K8s | `kubectl rollout restart deployment/authentik-server -n authentik` |
| Jellyfin | K8s | `kubectl rollout restart deployment/jellyfin -n media` |
| GitLab | VM | `ssh gitlab 'gitlab-ctl restart'` |
| Harbor | VM | `ssh harbor 'cd /opt/harbor && docker-compose restart'` |
| NetBox | VM | `ssh netbox 'systemctl restart netbox netbox-rq'` |
| HAProxy | VM | `ssh haproxy-1 'systemctl restart haproxy'` |

## Kubernetes Services

### Standard Deployment Restart

```bash
# Restart a deployment (rolling update, zero downtime)
kubectl rollout restart deployment/<name> -n <namespace>

# Watch rollout progress
kubectl rollout status deployment/<name> -n <namespace>

# Check pod status
kubectl get pods -n <namespace> -l app.kubernetes.io/name=<app>
```

### StatefulSet Restart

```bash
# Restart statefulset (one pod at a time)
kubectl rollout restart statefulset/<name> -n <namespace>

# Watch rollout
kubectl rollout status statefulset/<name> -n <namespace>
```

### DaemonSet Restart

```bash
# Restart daemonset (affects all nodes)
kubectl rollout restart daemonset/<name> -n <namespace>

# Watch rollout
kubectl rollout status daemonset/<name> -n <namespace>
```

### Force Pod Recreation

```bash
# Delete pods (deployment will recreate)
kubectl delete pods -n <namespace> -l app.kubernetes.io/name=<app>

# Force immediate termination (use sparingly)
kubectl delete pods -n <namespace> -l app.kubernetes.io/name=<app> --grace-period=0 --force
```

### Flux-Managed Services

```bash
# Trigger Flux reconciliation (pulls latest from Git)
flux reconcile kustomization <name> --with-source

# Suspend/Resume for maintenance
flux suspend kustomization <name>
flux resume kustomization <name>

# Check Flux status
flux get kustomizations
flux get helmreleases -A
```

## VM-Based Services

### GitLab

```bash
# Full restart
ssh gitlab "gitlab-ctl restart"

# Restart specific component
ssh gitlab "gitlab-ctl restart puma"
ssh gitlab "gitlab-ctl restart sidekiq"
ssh gitlab "gitlab-ctl restart nginx"

# Check status
ssh gitlab "gitlab-ctl status"

# Reconfigure (after config changes)
ssh gitlab "gitlab-ctl reconfigure"
```

### Harbor

```bash
# Restart all containers
ssh harbor "cd /opt/harbor && docker-compose restart"

# Restart specific service
ssh harbor "cd /opt/harbor && docker-compose restart core"
ssh harbor "cd /opt/harbor && docker-compose restart registry"

# Check status
ssh harbor "cd /opt/harbor && docker-compose ps"

# View logs
ssh harbor "cd /opt/harbor && docker-compose logs -f core"
```

### NetBox

```bash
# Restart NetBox services
ssh netbox "systemctl restart netbox netbox-rq"

# Restart just web interface
ssh netbox "systemctl restart netbox"

# Restart background workers
ssh netbox "systemctl restart netbox-rq"

# Restart Redis (cache)
ssh netbox "systemctl restart redis"

# Restart PostgreSQL (database)
ssh netbox "systemctl restart postgresql"

# Check status
ssh netbox "systemctl status netbox netbox-rq"
```

### HAProxy

```bash
# Graceful reload (no connection drop)
ssh haproxy-1 "systemctl reload haproxy"
ssh haproxy-2 "systemctl reload haproxy"

# Full restart
ssh haproxy-1 "systemctl restart haproxy"

# Check status
ssh haproxy-1 "systemctl status haproxy"

# Verify configuration before restart
ssh haproxy-1 "haproxy -c -f /etc/haproxy/haproxy.cfg"
```

### TrueNAS Services

```bash
# Restart NFS
ssh truenas "systemctl restart nfs-server"

# Restart SMB
ssh truenas "systemctl restart smbd nmbd"

# Restart iSCSI
ssh truenas "systemctl restart tgtd"

# Via TrueNAS API
curl -X POST "https://truenas.example.com/api/v2.0/service/restart" \
  -H "Authorization: Bearer $TRUENAS_API_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"service": "nfs"}'
```

## Service-Specific Procedures

### Traefik (Ingress Controller)

**Impact**: Brief interruption to all HTTP/HTTPS traffic

```bash
# Restart Traefik
kubectl rollout restart deployment/traefik -n traefik

# Verify IngressRoutes are working
kubectl get ingressroute -A

# Check Traefik dashboard
curl -s https://traefik.example.com/dashboard/ | head
```

### Authentik (SSO)

**Impact**: Users may need to re-authenticate

```bash
# Restart Authentik server
kubectl rollout restart deployment/authentik-server -n authentik

# Restart Authentik worker
kubectl rollout restart deployment/authentik-worker -n authentik

# Check health
curl -s https://auth.example.com/-/health/live/
```

### Prometheus/Grafana (Monitoring)

**Impact**: Temporary gap in metrics collection

```bash
# Restart Prometheus
kubectl rollout restart statefulset/prometheus-kube-prometheus-prometheus -n monitoring

# Restart Grafana
kubectl rollout restart deployment/grafana -n monitoring

# Verify metrics collection
curl -s http://prometheus.example.com/api/v1/query?query=up | jq
```

### PostgreSQL (Database)

**Impact**: Applications using database will error briefly

```bash
# CloudNative-PG managed
kubectl rollout restart cluster/postgres -n databases

# Check cluster status
kubectl get cluster -n databases

# For VM-based PostgreSQL
ssh <host> "systemctl restart postgresql"
```

## Ansible Playbook Restarts

For orchestrated restarts across multiple hosts:

```bash
# Restart specific service across all hosts
ansible-playbook -i ansible/inventory/hosts.yml ansible/playbooks/service-restart.yml \
  -e service_name=<service> -e target_hosts=<group>
```

## Troubleshooting Failed Restarts

### Kubernetes Pod Stuck

```bash
# Check pod events
kubectl describe pod <pod-name> -n <namespace>

# Check logs
kubectl logs <pod-name> -n <namespace>

# Force delete stuck pod
kubectl delete pod <pod-name> -n <namespace> --grace-period=0 --force
```

### VM Service Won't Start

```bash
# Check service status
systemctl status <service>

# Check journal logs
journalctl -u <service> -n 50

# Check for port conflicts
ss -tlnp | grep <port>

# Check disk space
df -h
```

## Post-Restart Verification

After any restart, verify:

1. **Service is running**:

   ```bash
   # Kubernetes
   kubectl get pods -n <namespace>

   # VM
   systemctl status <service>
   ```

2. **Health check passes**:

   ```bash
   curl -s https://<service>.example.com/health
   ```

3. **No errors in logs**:

   ```bash
   # Kubernetes
   kubectl logs -n <namespace> deployment/<name> --tail=50

   # VM
   journalctl -u <service> -n 50
   ```

4. **Monitoring shows healthy**:
 - Check Grafana dashboards
 - Verify no new alerts

## Related Files

| File | Purpose |
|------|---------|
| `ansible/playbooks/service-restart.yml` | Ansible service restart |
| `kubernetes/apps/*/` | Kubernetes app configurations |
| `docs/runbooks/troubleshooting/` | Issue-specific troubleshooting |
