# group_vars/

Per-group variable files that customize role behavior for each host group.

## Files

| File | Group | Purpose |
|------|-------|---------|
| `all.yml` | All hosts | Global defaults: domain, DNS, SSH, firewall, fail2ban, sudo, versions |
| `proxmox.yml` | Proxmox | Root SSH access, IOMMU, PVE ports, ZFS tuning |
| `infrastructure.yml` | infrastructure | Docker CE, HTTP/HTTPS/SSH ports, Docker sudo commands |
| `dns.yml` | DNS | DNS (53), AdGuard Web UI (3000) ports |
| `k8s_cluster.yml` | k8s_cluster | RKE2 version, CNI (Cilium), cluster CIDRs, API VIP, kubelet args |
| `masters.yml` | masters | K8s API (6443), etcd (2379-2380), Cilium, MetalLB ports |
| `workers.yml` | workers | NodePort range (30000-32767), Cilium, MetalLB ports |
| `load_balancers/vars.yml` | load_balancers | HAProxy stats port (9000), K8s API (6443), keepalived commands |
| `amp_servers.yml` | amp_servers | AMP Web UI (8081), game server ports (25000-25199) |
| `vpn_servers.yml` | vpn_servers | WireGuard (51820), wg-easy Web UI (51821) |
| `storage.yml` | storage | NFS (2049), iSCSI (3260), RPC (111) ports |
| `ci_runner.yml` | ci_runner | Docker CE, GitLab Runner executor config, metrics port (9252) |

## all.yml -- Global Defaults

### Network and Domain

- `domain`: `example.com`
- `timezone`: `America/Chicago`
- `dns_servers`: AdGuard Home (<internal-ip>), Cloudflare (1.1.1.1)
- `ntp_servers`: 0.pool.ntp.org, 1.pool.ntp.org

### Key Infrastructure IPs

- `truenas_ip`, `gitlab_ip`, `harbor_ip`, `netbox_ip`, `adguard_ip`
- `haproxy_vip` (<internal-ip>), `traefik_ip` (<internal-ip>)

### SSH Hardening

- Port 22, key-only auth, no root login, strong ciphers
- Allowed users: `debian automation`
- Authorized keys for automation and desktop

### Firewall

- Default deny incoming, allow outgoing
- Base port: SSH (22)
- Each group adds `firewall_extra_ports`

### Fail2ban

- Max retries: 3, ban time: 3600s, find time: 600s
- Ignored subnets: localhost, infrastructure (<vlan-cidr>), Kubernetes (<vlan-cidr>)

### Sudo

- User: `debian`
- Base commands: `systemctl status`, `journalctl`
- Each group adds `sudo_extra_commands`

### Version Pins (SSOT)

All managed software versions are pinned here:

- `gitlab_version`: 18.8.0-ce.0
- `harbor_version`: 2.12.2
- `promtail_version`: 3.6.8
- `gitlab_runner_version`: 18.10.0

## k8s_cluster.yml -- Kubernetes Configuration

- `rke2_version`: v1.34.3+rke2r3
- `rke2_cni`: Cilium
- `rke2_api_ip`: HAProxy VIP (<internal-ip>)
- `rke2_cluster_cidr`: 10.42.0.0/16
- `rke2_service_cidr`: 10.43.0.0/16
- Disables bundled ingress-nginx (Traefik used instead)
- Kubelet args: max-pods=150, pod-pids-limit=4096

## load_balancers/vars.yml

- `haproxy_stats_port`: 9000
- `haproxy_stats_user`: admin
- Credentials sourced from SOPS SSOT via `creds.infrastructure.haproxy.*`

## Variable Precedence

Group vars are merged by Ansible's standard precedence:
1. `all.yml` (lowest priority)
2. Parent group vars (e.g., `k8s_cluster.yml`)
3. Child group vars (e.g., `masters.yml`, `workers.yml`)
4. Host vars (defined in `hosts.yml`)

Variables like `firewall_extra_ports` and `sudo_extra_commands` are overridden (not merged) at each level, so each group file defines the complete set for that group.
