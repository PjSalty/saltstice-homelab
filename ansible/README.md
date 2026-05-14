# Ansible

Host configuration and day-2 ops. Roles target Debian 13 specifically.
Inventory is a mix of static hosts.yml and dynamic NetBox lookup.

## Roles

| Role | Scope |
|---|---|
| `common` | timezone, sysctl hardening, chrony NTP, node_exporter, DNS resolver |
| `ssh` | sshd hardening, key-only auth, X11 + agent forwarding off |
| `firewall` | UFW with per-group allowlists |
| `fail2ban` | brute-force protection, UFW banaction |
| `sudo` | role-based command allowlists, no NOPASSWD |
| `auto-updates` | unattended-upgrades, security-only |
| `docker` | Docker CE repo, daemon config, Harbor mirror |
| `qemu-guest-agent` | Proxmox VM introspection |
| `certificates` | TLS cert push from cert-manager to non-K8s VMs |
| `proxmox` | hypervisor sysctl, GPU passthrough, IOMMU, NVMe tuning |
| `proxmox-maintenance` | QEMU hooks, LVM snapshots, kernel module mgmt |
| `k8s-prereqs` | kubelet tuning, CRI socket, Karpenter prerequisites |
| `gpu` | NVIDIA driver + CUDA + containerd integration |
| `haproxy` | K8s API LB + keepalived VIP failover |
| `adguard` | DNS appliance |
| `netbox` | IPAM service |
| `harbor` | container registry hardening + GC + replication |
| `gitlab` | self-hosted GitLab |
| `gitlab-runner` | CI runner config |
| `amp` | game server |
| `vpn` | WireGuard tunnel |
| `lablabs.rke2` | RKE2 install (upstream Ansible Galaxy role) |

## Playbooks

### Bootstrap (one-time, in order)

1. `00-proxmox.yml`, hypervisor prep
2. `01-vms.yml`, VM provisioning trigger (Terraform applies, this verifies)
3. `02-base.yml`, common hardening on every VM
4. `03-services.yml`, service-specific roles per VM
5. `04-k8s.yml`, RKE2 install on masters then workers
6. `05-flux.yml`, Flux bootstrap into the cluster
7. `06-verify.yml`, post-deploy verification

### Operations (idempotent, run as needed)

- `patch-systems.yml`, `dist-upgrade` with serial reboot logic
- `patch-proxmox.yml`, Proxmox-specific patch path
- `rolling-reboot.yml`, controlled fleet reboot with health checks
- `scale-cluster.yml`, Karpenter NodePool scaling triggers
- `deploy-certificates.yml`, push cert-manager TLS to VMs
- `deploy-automation-user.yml`, create the `automation` user with key
- `build-karpenter-template.yml`, Proxmox VM template for Karpenter
- `backup-verify.yml`, Velero + TrueNAS snapshot + Proxmox vzdump
 freshness checks
- `audit-config-drift.yml`, config sync verification
- `upgrade-rke2.yml`, RKE2 cluster rolling upgrade
- `restart-harbor.yml`, `truenas-update.yml`, service-specific updates
- `99-rotate-credentials.yml`, full credential rotation pipeline
 (see [`docs/adrs/credential-rotation.md`](../docs/adrs/) when published)

## Inventory

- `hosts.yml`, static prod hosts
- `seed_inventory.yml`, bootstrap template
- `bootstrap.yml`, ephemeral Proxmox inventory (NetBox-derived)
- `netbox.yml`, dynamic inventory pulled from NetBox API
- `group_vars/`, common, k8s_nodes, infrastructure, storage, dmz,

## Credential management

`credentials.sops.yaml` is the SSOT for every credential the playbooks
need. SOPS-Age encrypted. The rotation playbook
(`99-rotate-credentials.yml`) generates new credentials per-service,
applies them, validates, and only then promotes them in the SSOT.
Rollback on any validation failure.

## What stays out of CI

The credential rotation playbook is run from Semaphore on schedule, not
GitLab CI. CI runners don't get the SOPS Age key.
