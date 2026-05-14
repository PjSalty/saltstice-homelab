# inventory/

Ansible inventory definitions for the Salty Homelab infrastructure.

## Files

| File | Purpose |
|------|---------|
| `hosts.yml` | Primary static inventory -- all VMs grouped by VLAN and function |
| `bootstrap.yml` | Bootstrap-phase inventory using root user and pre-VLAN IPs |
| `netbox.yml` | NetBox dynamic inventory plugin configuration |
| `seed_inventory.yml` | Phase 0 seed inventory with full VM hardware specs (pre-NetBox) |

## hosts.yml

The primary inventory file used by `site.yml` and all day-2 operations. Organizes hosts by VLAN:

| Group | VLAN | Subnet | Hosts |
|-------|------|--------|-------|
| `proxmox` | 30 | 10.x0.0/24 | Proxmox-salty (10.x0.100) |
| `dns` | 20 | <vlan-cidr> | AdGuard (<internal-ip>) |
| `infrastructure` | 20 | <vlan-cidr> | GitLab, Harbor, NetBox |
| `ci_runner` | 20 | <vlan-cidr> | ci-runner (<internal-ip>) |
| `amp_servers` | 20 | <vlan-cidr> | amp (<internal-ip>) |
| `load_balancers` | 20 | <vlan-cidr> | HAProxy-1 (<internal-ip>), HAProxy-2 (<internal-ip>) |
| `k8s_cluster` | 30 | 10.x0.0/24 | masters + workers (parent group) |
| `masters` | 30 | 10.x0.0/24 | K8s-master-1/2/3 (10.x0.10-12) |
| `workers` | 30 | 10.x0.0/24 | K8s-worker-1/2/3 (10.x0.20-22) |
| `gpu_workers` | 30 | 10.x0.0/24 | K8s-worker-1 (has_gpu: true) |
| `storage` | 40 | <vlan-cidr> | TrueNAS (<internal-ip>) |
| `vpn_servers` | 60 | <vlan-cidr> | vpn (<internal-ip>) |

### Global Variables (defined in hosts.yml)

- `ansible_user`: `automation` (all hosts except Proxmox/TrueNAS which use root)
- `ansible_python_interpreter`: `/usr/bin/python3`
- `ansible_ssh_private_key_file`: `/root/.ssh/automation-key`
- `domain`: `example.com`
- `timezone`: `America/Chicago`

### Per-Host Variables

- `ansible_host` -- IP address for SSH connectivity
- `vm_id` -- Proxmox VM ID
- `cert_name` -- Certificate name used by the certificates role
- `vlan_id` -- VLAN assignment
- `haproxy_role` / `keepalived_priority` -- HAProxy HA role (master/backup)
- `has_gpu` / `gpu_type` -- GPU passthrough flags (workers only)

## bootstrap.yml

Used only during Phase 0 bootstrap, before the automation user and VLAN networking are in place. Connects as root with relaxed SSH host key checking. Uses pre-migration IP addresses (<mgmt-ip>/24 subnet).

## NetBox.yml

NetBox dynamic inventory plugin configuration. When enabled (requires `NETBOX_TOKEN` env var), queries NetBox at `netbox.example.com` and automatically groups hosts by:

- Sites, device roles, platforms, clusters
- Custom fields: GPU passthrough, SSO status, Terraform managed, backup status
- Computed K8s roles (master/worker)

Uses a 1-hour JSON file cache at `/tmp/netbox_inventory_cache`.

## seed_inventory.yml

Detailed bootstrap inventory documenting full VM hardware specifications including TrueNAS disk WWN passthrough identifiers, ZFS pool configuration, service ports, and storage requirements. Used during initial infrastructure deployment before NetBox becomes the source of truth.

### Deployment Order

1. TrueNAS (storage backend for others)
2. Harbor (container images)
3. GitLab (GitOps source)
4. NetBox (IPAM for Phase 1)
5. HAProxy (K8s API load balancer)

## group_vars/

See [group_vars/README.md](group_vars/README.md) for per-group variable documentation.
