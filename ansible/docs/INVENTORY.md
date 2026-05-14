# Inventory Reference

## Host Groups

| Group | Hosts | VLAN | Subnet |
|-------|-------|------|--------|
| Proxmox | Proxmox (<mgmt-ip>) | 1 | <mgmt-ip>/24 |
| DNS | AdGuard (<internal-ip>) | 20 | <vlan-cidr> |
| infrastructure | GitLab, Harbor, NetBox | 20 | <vlan-cidr> |
| load_balancers | HAProxy-1 (<internal-ip>), HAProxy-2 (<internal-ip>) | 20 | <vlan-cidr> |
| amp_servers | amp (<internal-ip>) | 20 | <vlan-cidr> |
| masters | K8s-master-1/2/3 (10.x0.10-12) | 30 | 10.x0.0/24 |
| workers | K8s-worker-1/2/3 (10.x0.20-22) | 30 | 10.x0.0/24 |
| k8s_cluster | masters + workers | 30 | 10.x0.0/24 |
| storage | TrueNAS (<internal-ip>) | 40 | <vlan-cidr> |
| vpn_servers | vpn (<internal-ip>) | 60 | <vlan-cidr> |

## Group Variables

| File | Scope | Key Variables |
|------|-------|---------------|
| `all.yml` | All hosts | domain, timezone, DNS, SSH, firewall defaults |
| `proxmox.yml` | Proxmox | SSH root access, PVE ports |
| `infrastructure.yml` | Docker hosts | Docker CE, service ports |
| `dns.yml` | AdGuard | DNS ports, admin UI |
| `k8s_cluster.yml` | All K8s | RKE2 version, CNI, CIDRs, API VIP |
| `masters.yml` | Control plane | K8s API, etcd, Cilium ports |
| `workers.yml` | Workers | NodePort range, Cilium ports |
| `load_balancers/vars.yml` | HAProxy | VIP, stats, K8s backends |
| `amp_servers.yml` | AMP | Game ports 25000-25199 |
| `vpn_servers.yml` | VPN | WireGuard 51820, wg-easy UI |
| `storage.yml` | TrueNAS | NFS, iSCSI, RPC ports |
