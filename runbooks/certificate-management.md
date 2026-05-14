# Certificate Management Runbook

## Overview

This runbook covers TLS certificate monitoring, renewal, and troubleshooting for the Salty Homelab.

**Certificate Authority**: Let's Encrypt (via cert-manager)
**DNS Provider**: Cloudflare (DNS-01 challenge)
**Wildcard Certificate**: `*.example.com`

## Monitoring Infrastructure

### Prometheus Alerts

Certificates are automatically monitored via Prometheus alerts defined in:
`kubernetes/monitoring/prometheus/base/rules/infrastructure-alerts.yaml`

| Alert | Threshold | Severity | Action |
|-------|-----------|----------|--------|
| `CertificateExpiringSoon` | < 7 days | Warning | Verify cert-manager renewal |
| `CertificateExpiryCritical` | < 24 hours | Critical | Manual intervention required |
| `CertificateNotReady` | Not ready > 30 min | Warning | Check cert-manager logs |

### Loki Log Alerts

Additional log-based monitoring in:
`kubernetes/infrastructure/loki/logql-alerting-rules.yaml`

| Alert | Pattern | Action |
|-------|---------|--------|
| `CertificateExpirationWarning` | Log entries matching `certificate.*expir` | Check affected service |

## Certificate Architecture

```
                    ┌┐
                          Cloudflare DNS         
                       (DNS-01 Challenge Zone)   
                    ┬┘
                                   
                    ┌▼┐
                           cert-manager          
                      (Automated Renewal)        
                    ┬┘
                                   
              ┌┼┐
                                                      
    ┌▼┐ ┌▼┐ ┌▼┐
     Traefik Ingress      Kubernetes        VM Services   
     (wildcard cert)      Secrets         (via Ansible)   
    ┘ ┘ ┘
```

## Checking Certificate Status

### Kubernetes Certificates

```bash
# List all certificates
kubectl get certificates -A

# Check certificate details
kubectl describe certificate <name> -n <namespace>

# Check certificate secret
kubectl get secret <cert-secret-name> -n <namespace> -o jsonpath='{.data.tls\.crt}' | base64 -d | openssl x509 -noout -dates

# View cert-manager logs
kubectl logs -n cert-manager -l app=cert-manager --tail=100

# Check certificate requests
kubectl get certificaterequest -A
```

### Traefik Wildcard Certificate

```bash
# Check the main wildcard cert
kubectl get certificate wildcard-salt-saltstice-com -n traefik

# View expiration
kubectl get secret wildcard-salt-saltstice-com-tls -n traefik -o jsonpath='{.data.tls\.crt}' | base64 -d | openssl x509 -noout -dates
```

### External Service Check

```bash
# Check certificate from outside
echo | openssl s_client -connect grafana.example.com:443 -servername grafana.example.com 2>/dev/null | openssl x509 -noout -dates
```

## Renewal Procedures

### Automatic Renewal (Normal Operation)

Cert-manager automatically renews certificates when:

- Certificate is within 30 days of expiration (2/3 of validity period)
- Certificate is marked as not ready

**No action required** - renewal is fully automated.

### Manual Renewal (If Automatic Fails)

1. **Delete the certificate secret** to force renewal:

```bash
kubectl delete secret wildcard-salt-saltstice-com-tls -n traefik
```

2. **Trigger certificate reconciliation**:

```bash
kubectl annotate certificate wildcard-salt-saltstice-com -n traefik cert-manager.io/issue-temporary-certificate="true"
```

3. **Watch for renewal**:

```bash
kubectl get certificaterequest -n traefik -w
```

### Emergency: Temporary Self-Signed Certificate

If Let's Encrypt is unavailable:

```bash
# Generate temporary self-signed cert
openssl req -x509 -nodes -days 30 -newkey rsa:2048 \
  -keyout /tmp/tls.key -out /tmp/tls.crt \
  -subj "/CN=*.example.com"

# Create/update secret
kubectl create secret tls wildcard-salt-saltstice-com-tls \
  --cert=/tmp/tls.crt --key=/tmp/tls.key \
  -n traefik --dry-run=client -o yaml | kubectl apply -f -
```

## Troubleshooting

### Certificate Not Renewing

1. **Check cert-manager controller logs**:

```bash
kubectl logs -n cert-manager deployment/cert-manager -f
```

2. **Check ClusterIssuer status**:

```bash
kubectl describe clusterissuer letsencrypt-prod
```

3. **Check for failed challenges**:

```bash
kubectl get challenges -A
kubectl describe challenge <name> -n <namespace>
```

### DNS-01 Challenge Failing

1. **Verify Cloudflare API token**:

```bash
kubectl get secret cloudflare-api-token -n cert-manager -o yaml
```

2. **Check DNS propagation**:

```bash
dig TXT _acme-challenge.example.com
```

3. **Common issues**:
 - API token lacks `Zone:DNS:Edit` permission
 - Zone ID incorrect in ClusterIssuer
 - DNS propagation delay (wait 5-10 minutes)

### Certificate Shows as Not Ready

1. **Check certificate events**:

```bash
kubectl describe certificate <name> -n <namespace>
```

2. **Check certificate request**:

```bash
kubectl get certificaterequest -n <namespace>
kubectl describe certificaterequest <name> -n <namespace>
```

3. **Force re-issue**:

```bash
# Delete failed certificate request
kubectl delete certificaterequest <name> -n <namespace>
# cert-manager will create a new one
```

## VM Certificate Management

VM services (Harbor, GitLab, NetBox) use certificates distributed via Ansible.

### Check VM Certificate Expiration

```bash
# SSH to VM and check
ssh gitlab 'openssl x509 -in /etc/gitlab/ssl/gitlab.example.com.crt -noout -dates'
```

### Renew VM Certificates

Run the certificate deployment playbook:

```bash
ansible-playbook ansible/playbooks/deploy-vm-certificates.yml
```

## Related Files

| File | Purpose |
|------|---------|
| `kubernetes/infrastructure/cert-manager/` | cert-manager configuration |
| `kubernetes/monitoring/prometheus/base/rules/infrastructure-alerts.yaml` | Certificate alerts |
| `kubernetes/infrastructure/loki/logql-alerting-rules.yaml` | Log-based alerts |
| `ansible/playbooks/deploy-vm-certificates.yml` | VM certificate deployment |
| `ansible/playbooks/manage-certificates.yml` | Certificate lifecycle management |

## Alert Response Checklist

### CertificateExpiringSoon (Warning)

- [ ] Check cert-manager logs for renewal activity
- [ ] Verify ClusterIssuer is healthy
- [ ] If no renewal activity, manually trigger (see above)
- [ ] Set reminder to verify renewal completed

### CertificateExpiryCritical (Critical)

- [ ] Immediately check cert-manager status
- [ ] Check for any pending challenges
- [ ] If challenge stuck, delete and retry
- [ ] If renewal impossible, deploy temporary self-signed
- [ ] Escalate to investigate root cause

### CertificateNotReady (Warning)

- [ ] Check certificate request status
- [ ] Review cert-manager logs for errors
- [ ] Verify DNS challenge can complete
- [ ] Check Cloudflare API token validity
