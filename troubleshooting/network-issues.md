# Network Issues Troubleshooting Guide

## Overview

This guide covers network connectivity issues, DNS problems, and firewall troubleshooting specific to application-level issues (for infrastructure network issues, see [runbooks/network-troubleshooting.md](../runbooks/network-troubleshooting.md)).

## Quick Reference

| Issue | Symptom | First Check |
|-------|---------|-------------|
| No connectivity | Timeout/refused | `ping`, `nc -zv` |
| DNS failure | Name not resolved | `dig`, `nslookup` |
| TLS error | Certificate errors | `openssl s_client` |
| Slow connection | High latency | `traceroute`, `mtr` |
| Service unreachable | 502/503 errors | Traefik, backend pods |

## Connectivity Diagnosis

### Basic Connectivity Tests

```bash
# Ping test (ICMP)
ping <target>

# TCP port test
nc -zv <host> <port>

# HTTP/HTTPS test
curl -v https://<service>.example.com

# From inside Kubernetes
kubectl run -it --rm debug --image=alpine -- sh
# Then: apk add curl bind-tools && curl -v <url>
```

### Trace Route

```bash
# Standard traceroute
traceroute <target>

# MTR for continuous monitoring
mtr <target>

# TCP traceroute (if ICMP blocked)
traceroute -T -p 443 <target>
```

## DNS Issues

### External DNS Not Resolving

```bash
# Test AdGuard DNS
dig @<internal-ip> google.com

# Test upstream DNS
dig @1.1.1.1 google.com

# Check if AdGuard is responding
curl -s http://<internal-ip>:3000/
```

**AdGuard issues**:

```bash
# Check AdGuard pod
kubectl get pods -n adguard

# Restart AdGuard
kubectl rollout restart deployment/adguard-home -n adguard

# Check AdGuard logs
kubectl logs -n adguard deployment/adguard-home
```

### Internal DNS Not Resolving

```bash
# Test specific internal name
dig @<internal-ip> gitlab.example.com

# Check if record exists
# AdGuard Admin  Filters  DNS Rewrites

# Check NetBox DNS sync
ansible-playbook ansible/playbooks/03-netbox-dns-sync.yml --check
```

### Kubernetes DNS Issues

```bash
# Check CoreDNS pods
kubectl get pods -n kube-system -l k8s-app=kube-dns

# Test from pod
kubectl run -it --rm debug --image=alpine -- nslookup kubernetes.default

# Check CoreDNS logs
kubectl logs -n kube-system -l k8s-app=kube-dns

# Verify CoreDNS ConfigMap
kubectl get configmap -n kube-system coredns -o yaml
```

**CoreDNS not resolving external**:

```bash
# Check upstream servers in CoreDNS config
kubectl get configmap -n kube-system coredns -o yaml | grep forward

# Should forward to AdGuard or upstream DNS
```

**Service DNS not working**:

```bash
# Check service exists
kubectl get svc -n <namespace> <service>

# Check endpoints exist
kubectl get endpoints -n <namespace> <service>

# Full DNS name format: <service>.<namespace>.svc.cluster.local
```

## TLS/Certificate Issues

### Certificate Validation Failed

```bash
# Check certificate details
openssl s_client -connect <host>:443 -servername <host> </dev/null 2>/dev/null | openssl x509 -noout -text

# Check certificate chain
openssl s_client -connect <host>:443 -servername <host> -showcerts </dev/null 2>/dev/null

# Check expiration
echo | openssl s_client -connect <host>:443 -servername <host> 2>/dev/null | openssl x509 -noout -dates
```

**Certificate expired**:
See [runbooks/certificate-management.md](../runbooks/certificate-management.md)

**Certificate name mismatch**:

```bash
# Check certificate SAN/CN
openssl s_client -connect <host>:443 -servername <host> </dev/null 2>/dev/null | \
  openssl x509 -noout -subject -ext subjectAltName

# Make sure accessing service by correct hostname
```

**Self-signed certificate**:

```bash
# For internal services, make sure CA is trusted
# Add CA to system trust store or application config

# Check Harbor CA distribution
ansible-playbook ansible/playbooks/10-configure-harbor-ca.yml
```

## Traefik/Ingress Issues

### 502 Bad Gateway

**Backend service not running**:

```bash
# Check if backend pods exist
kubectl get pods -n <namespace> -l app=<app>

# Check if pods are ready
kubectl get pods -n <namespace> -l app=<app> -o wide

# Check service endpoints
kubectl get endpoints -n <namespace> <service>
```

**Backend not responding**:

```bash
# Test backend directly (from within cluster)
kubectl run -it --rm debug --image=alpine -- wget -qO- http://<service>.<namespace>.svc:<port>

# Check backend logs
kubectl logs -n <namespace> deployment/<app>
```

### 503 Service Unavailable

```bash
# Usually means no healthy backends
kubectl get endpoints -n <namespace> <service>

# Check readiness probe
kubectl describe pod -n <namespace> <pod> | grep -A 5 Readiness

# If probe failing, check application health
kubectl exec -it -n <namespace> <pod> -- curl localhost:8080/health
```

### 404 Not Found

```bash
# Check IngressRoute exists
kubectl get ingressroute -n <namespace>

# Check IngressRoute matches
kubectl describe ingressroute -n <namespace> <name>

# Verify hostname in IngressRoute matches request
```

### Traefik Debugging

```bash
# Check Traefik logs
kubectl logs -n traefik deployment/traefik

# Check Traefik dashboard
# https://traefik.example.com/dashboard/

# List all routers
kubectl get ingressroute -A

# Check middleware
kubectl get middleware -A
```

## Service Mesh (Cilium) Issues

### Pod-to-Pod Connectivity

```bash
# Check Cilium status
kubectl -n kube-system exec -it ds/cilium -- cilium status

# Run connectivity test
kubectl -n kube-system exec -it ds/cilium -- cilium connectivity test

# Check specific pod's Cilium endpoint
kubectl -n kube-system exec -it ds/cilium -- cilium endpoint list
```

### Network Policy Blocking

```bash
# List NetworkPolicies
kubectl get networkpolicy -A

# Check if policy applies to pod
kubectl describe networkpolicy -n <namespace> <policy>

# Temporarily delete policy to test (be careful!)
kubectl delete networkpolicy -n <namespace> <policy>
```

## Load Balancer Issues

### HAProxy Not Working

```bash
# Check HAProxy status
ssh haproxy-1 "systemctl status haproxy"
ssh haproxy-2 "systemctl status haproxy"

# Check HAProxy logs
ssh haproxy-1 "journalctl -u haproxy -n 100"

# Check backend health
ssh haproxy-1 "echo 'show stat' | socat /var/run/haproxy.sock stdio"

# Test config before reload
ssh haproxy-1 "haproxy -c -f /etc/haproxy/haproxy.cfg"
```

### Kubernetes API Unreachable

```bash
# Check HAProxy VIP
ping <internal-ip>

# Check if HAProxy is forwarding to masters
curl -k https://<internal-ip>:6443/healthz

# Check individual masters
for i in 1 2 3; do
  curl -k https://k8s-master-$i:6443/healthz
done
```

## Firewall Issues

### MikroTik Firewall

```bash
# SSH to router
ssh admin@<mgmt-ip>

# List filter rules
/ip firewall filter print

# Check traffic counters
/ip firewall filter print stats

# Check NAT rules
/ip firewall nat print

# Check connection tracking
/ip firewall connection print where dst-address=<ip>
```

### Host Firewall (iptables/nftables)

```bash
# Check iptables rules
sudo iptables -L -n -v

# Check nftables rules
sudo nft list ruleset

# Check if specific port is allowed
sudo iptables -L -n | grep <port>
```

## Common Patterns

### Service Works Internally But Not Externally

1. Check Traefik IngressRoute
2. Check DNS resolves correctly
3. Check firewall allows traffic
4. Check certificate is valid

### Service Works from One Node But Not Another

1. Check network policy
2. Check Cilium endpoint status
3. Check node-specific routes
4. Check VLAN tagging

### Intermittent Connectivity

1. Check for resource exhaustion (CPU, memory)
2. Check for network saturation
3. Check for failing health checks
4. Check for DNS caching issues

## Debugging Commands

```bash
# Kubernetes pod networking
kubectl exec -it <pod> -n <namespace> -- ip addr
kubectl exec -it <pod> -n <namespace> -- ip route
kubectl exec -it <pod> -n <namespace> -- cat /etc/resolv.conf

# Capture packets (on node)
tcpdump -i any host <ip> and port <port>

# Check socket states
ss -tlnp  # Listening TCP
ss -ulnp  # Listening UDP
ss -tnp   # Established TCP

# Check network interfaces
ip link show
ip addr show
```

## Related Files

| File | Purpose |
|------|---------|
| [runbooks/network-troubleshooting.md](../runbooks/network-troubleshooting.md) | Infrastructure network |
| `kubernetes/infrastructure/cilium/` | Cilium CNI config |
| `kubernetes/infrastructure/traefik/` | Traefik config |
| `ansible/playbooks/08-deploy-haproxy.yml` | HAProxy setup |
