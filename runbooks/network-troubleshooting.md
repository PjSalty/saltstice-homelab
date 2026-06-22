# Network Troubleshooting Runbook

## Overview

Network troubleshooting: DNS, connectivity, and firewall/VLAN config.

## Network Architecture

```
                              Internet
                                 
                         ┌▼┐
                            RB4011      
                            Router      
                           <mgmt-ip>  
                         ┬┘
                                 
                         ┌▼┐
                            CRS317      
                            10G Switch  
                           <mgmt-ip>  
                         ┬┘
                                 
      ┌┬┼┬┐
                                                        
┌▼┐ ┌▼┐    ┌▼┐  ┌▼┐ ┌▼┐
 VLAN 1    VLAN 20       VLAN 30      VLAN 40  VLAN 60
Management Infra       Kubernetes     Storage    DMZ  
192.168.1  <internal-net>      <internal-net>       10.10.40 10.10.60
┘ ┘    ┘  ┘ ┘
```

## VLAN Reference

| VLAN | Name | Subnet | Gateway | Purpose |
|------|------|--------|---------|---------|
| 1 | Management | <mgmt-ip>/24 | <mgmt-ip> | Network devices |
| 20 | Infrastructure | <vlan-cidr> | <internal-ip> | VMs, core services |
| 30 | Kubernetes | <vlan-cidr> | <internal-ip> | K8s nodes/pods |
| 40 | Storage | <vlan-cidr> | <internal-ip> | NFS, iSCSI |
| 60 | DMZ | <vlan-cidr> | <internal-ip> | VPN, public-facing |

## Quick Diagnosis

```bash
# Check basic connectivity
ping <target-ip>

# Check DNS resolution
dig <hostname>.example.com
nslookup <hostname>.example.com

# Check route to target
traceroute <target-ip>

# Check if port is open
nc -zv <ip> <port>

# Check local network interfaces
ip addr
ip route
```

## Scenario 1: DNS Resolution Failing

### Symptoms

- Services not resolving by name
- `dig` or `nslookup` failing
- Applications showing DNS errors

### Diagnosis

```bash
# Check AdGuard is reachable
ping adguard.example.com
ping <internal-ip>  # AdGuard IP

# Test DNS directly
dig @<internal-ip> gitlab.example.com

# Check if it's a specific record
dig @<internal-ip> <failing-hostname>.example.com

# Check upstream DNS
dig @1.1.1.1 google.com
```

### Common Fixes

**AdGuard service down**:

```bash
# Restart AdGuard (Kubernetes)
kubectl rollout restart deployment/adguard-home -n adguard

# Or if VM-based
ssh adguard "systemctl restart adguard-home"
```

**DNS record missing**:

```bash
# Check NetBox for correct DNS records
# Add via NetBox or AdGuard admin UI

# Sync DNS from NetBox
ansible-playbook ansible/playbooks/03-netbox-dns-sync.yml
```

**Client pointing to wrong DNS**:

```bash
# Check /etc/resolv.conf
cat /etc/resolv.conf

# Should show:
# nameserver <internal-ip>

# Fix via DHCP or static config
```

### Kubernetes DNS Issues

```bash
# Check CoreDNS pods
kubectl get pods -n kube-system -l k8s-app=kube-dns

# Check CoreDNS logs
kubectl logs -n kube-system -l k8s-app=kube-dns

# Test DNS from a pod
kubectl run -it --rm debug --image=alpine -- nslookup kubernetes.default

# Check CoreDNS configmap
kubectl get configmap -n kube-system coredns -o yaml
```

## Scenario 2: Cannot Reach Service

### Symptoms

- Service URL times out
- `curl` hangs or fails
- Browser shows connection refused

### Diagnosis Flow

```
1. Can you ping the host?
   NO  Network/routing issue
   YES ↓

2. Is the port open?
   NO  Service not running or firewall
   YES ↓

3. Does DNS resolve correctly?
   NO  DNS issue (see Scenario 1)
   YES ↓

4. Is Traefik routing working?
   NO  Check IngressRoute
   YES  Check service/pod logs
```

### Network Reachability

```bash
# Ping test
ping <service-ip>

# Port test
nc -zv <ip> 443
nc -zv <ip> 80

# Full connection test
curl -v https://<service>.example.com
```

### Firewall Issues (MikroTik)

```bash
# Check firewall rules (from router)
ssh admin@<mgmt-ip> "/ip firewall filter print"

# Check NAT rules
ssh admin@<mgmt-ip> "/ip firewall nat print"

# Check if traffic is being dropped
ssh admin@<mgmt-ip> "/ip firewall filter print stats"
```

### Traefik Routing

```bash
# Check IngressRoute exists
kubectl get ingressroute -A

# Check Traefik logs
kubectl logs -n traefik deployment/traefik

# Check if service endpoints exist
kubectl get endpoints -n <namespace> <service-name>

# Test from inside cluster
kubectl run -it --rm debug --image=alpine -- wget -qO- http://<service>.<namespace>.svc
```

## Scenario 3: Inter-VLAN Connectivity Issues

### Symptoms

- VMs in different VLANs can't communicate
- Kubernetes can't reach storage
- Services timeout when crossing VLANs

### Diagnosis

```bash
# Check routing table
ip route

# Trace route to destination
traceroute <destination-ip>

# Check if it's a firewall issue
# Temporarily add permissive rule for testing
```

### Common Fixes

**Missing route**:

```bash
# Add route on VM (temporary)
sudo ip route add <dest-network> via <gateway>

# Permanent fix: Update Ansible/cloud-init config
```

**VLAN tagging issue**:

```bash
# Check VLAN on interface
ip -d link show eth0

# Verify VLAN in Proxmox VM config
ssh proxmox "qm config <vmid> | grep net"
```

**Router firewall blocking**:

```bash
# Check MikroTik inter-VLAN rules
ssh admin@<mgmt-ip> "/ip firewall filter print where chain=forward"
```

## Scenario 4: Kubernetes Network Issues

### Pod-to-Pod Communication Failing

```bash
# Check Cilium status
kubectl -n kube-system exec -it ds/cilium -- cilium status

# Check Cilium connectivity
kubectl -n kube-system exec -it ds/cilium -- cilium connectivity test

# Check if NetworkPolicy is blocking
kubectl get networkpolicy -A
```

### Pod Cannot Reach External Services

```bash
# Test from pod
kubectl run -it --rm debug --image=alpine -- wget -qO- http://google.com

# Check if it's DNS
kubectl run -it --rm debug --image=alpine -- nslookup google.com

# Check egress NetworkPolicy
kubectl get networkpolicy -A -o yaml | grep -A 10 egress
```

### Service Not Accessible

```bash
# Check service
kubectl get svc -n <namespace> <service-name>

# Check endpoints (are pods selected?)
kubectl get endpoints -n <namespace> <service-name>

# Check pod labels match service selector
kubectl get pods -n <namespace> --show-labels
kubectl get svc -n <namespace> <service-name> -o yaml | grep selector -A 5
```

## Scenario 5: VPN Connectivity Issues

### WireGuard VPN Not Connecting

```bash
# Check VPN VM is running
ping vpn.example.com

# Check WireGuard service
ssh vpn "wg show"

# Check firewall allows WireGuard port (51820)
# On router:
ssh admin@<mgmt-ip> "/ip firewall filter print where dst-port=51820"
```

### VPN Connected But No Access

```bash
# Check VPN client routes
wg show
ip route

# Check if traffic is going through VPN
traceroute <internal-ip>

# Check VPN server routing
ssh vpn "ip route"
ssh vpn "iptables -L -n -v"
```

## Diagnostic Commands Reference

### General Network

```bash
# Show all interfaces
ip addr

# Show routing table
ip route

# Show ARP table
ip neigh

# Show listening ports
ss -tlnp

# Show established connections
ss -tnp

# Packet capture
tcpdump -i any host <ip>
```

### DNS

```bash
# Query DNS server
dig @<dns-server> <hostname>

# Reverse lookup
dig -x <ip>

# Check all records
dig <hostname> ANY
```

### HTTP/HTTPS

```bash
# Verbose curl
curl -v https://<url>

# Check certificate
openssl s_client -connect <host>:443 -servername <host>

# Follow redirects
curl -L <url>

# Check headers only
curl -I <url>
```

## Post-Troubleshooting

After resolving network issues:

- [ ] Verify all services accessible
- [ ] Check monitoring for alerts
- [ ] Document root cause
- [ ] Update firewall rules if needed
- [ ] Update this runbook if new scenario

## Related Files

| File | Purpose |
|------|---------|
| `ansible/playbooks/00-proxmox-network.yml` | Proxmox network setup |
| `ansible/roles/network/` | Network configuration |
| `kubernetes/infrastructure/cilium/` | Cilium CNI config |
| `config/network.yaml` | Network definitions |
