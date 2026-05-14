# firewall

UFW (Uncomplicated Firewall) configuration with default deny incoming, allow outgoing, and per-group port allowlists.

## Tasks (tasks/main.yml)

1. Install UFW
2. Set default deny incoming
3. Set default allow outgoing
4. Allow base ports (SSH by default)
5. Allow extra ports (per-group from `firewall_extra_ports`)
6. Enable UFW

## Variables (defaults/main.yml)

| Variable | Default | Description |
|----------|---------|-------------|
| `firewall_default_policy` | `deny` | Default incoming policy |
| `firewall_base_ports` | `[{port: 22, proto: tcp}]` | Ports open on all hosts |
| `firewall_extra_ports` | `[]` | Per-group additional ports (override in group_vars) |

### Per-Group Port Assignments

Each group_vars file overrides `firewall_extra_ports`:

- **Proxmox**: 8006 (Web UI), 5900-5999 (VNC), 3128 (SPICE), 9100 (node_exporter), 111 (RPC/NFS)
- **infrastructure**: 80, 443, 2222 (GitLab SSH), 9100
- **masters**: 6443 (API), 9345 (RKE2), 2379-2380 (etcd), 10250 (kubelet), 8472/UDP (VXLAN), Cilium, MetalLB
- **workers**: 10250 (kubelet), 8472/UDP (VXLAN), 30000-32767 (NodePort), Cilium, MetalLB
- **load_balancers**: 6443, 9345, 9000 (stats), 8405 (Prometheus)
- **DNS**: 53 (DNS), 80, 443, 3000 (AdGuard UI)
- **storage**: 80, 443, 111 (RPC), 2049 (NFS), 3260 (iSCSI)
- **amp_servers**: 8081 (Web UI), 25000-25199 (game servers)
- **vpn_servers**: 51820/UDP (WireGuard), 51821 (wg-easy UI)

## Tags

`firewall`, `packages`

## Dependencies

None.
