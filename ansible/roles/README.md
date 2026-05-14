# roles/

Ansible roles for the Salty Homelab infrastructure. Each role is self-contained with defaults, tasks, templates, handlers, and metadata.

## Role Categories

### Security Baseline (applied to all hosts)

| Role | Description |
|------|-------------|
| [common](common/) | Base OS: packages, timezone, sysctl, NTP, DNS, node_exporter |
| [automation_user](automation_user/) | CI/CD automation user with SSH key and NOPASSWD sudo |
| [SSH](ssh/) | SSH hardening: key-only auth, strong ciphers, remove insecure keys |
| [firewall](firewall/) | UFW default deny, per-group port allowlists |
| [fail2ban](fail2ban/) | Brute force protection with UFW ban action |
| [sudo](sudo/) | Minimal privilege sudoers with per-group command allowlists |
| [auto-updates](auto-updates/) | Unattended-upgrades for security patches |
| [qemu-guest-agent](qemu-guest-agent/) | Proxmox VM introspection agent |
| [promtail](promtail/) | Log shipping to Loki (journal, varlog, Docker) |

### Infrastructure Services

| Role | Description |
|------|-------------|
| [Docker](docker/) | Docker CE from official repo with Harbor mirror |
| [certificates](certificates/) | TLS cert deployment from cert-manager to VMs |
| [GitLab](gitlab/) | GitLab CE via Docker Compose |
| [Harbor](harbor/) | Harbor registry via offline installer + API bootstrap |
| [NetBox](netbox/) | NetBox IPAM via Docker Compose (PostgreSQL + Redis) |
| [HAProxy](haproxy/) | HAProxy + keepalived HA pair for K8s API LB |
| [GitLab-runner](gitlab-runner/) | GitLab Runner with Docker executor (host networking) |

### Kubernetes

| Role | Description |
|------|-------------|
| [K8s-prereqs](k8s-prereqs/) | Kernel modules, sysctl, swap, iSCSI, Cilium/CoreDNS configs |
| [GPU](gpu/) | NVIDIA drivers + container toolkit for GPU workers |
| [lablabs.RKE2](lablabs.rke2/) | RKE2 cluster deployment (vendored third-party role) |

### Hypervisor

| Role | Description |
|------|-------------|
| [Proxmox](proxmox/) | Proxmox VE hardening: IOMMU, ZFS tuning, SSD scheduler |

### Applications

| Role | Description |
|------|-------------|
| [amp](amp/) | CubeCoders AMP game server via Docker Compose |
| [vpn](vpn/) | WireGuard VPN via wg-easy Docker container |

## Role Application Order (site.yml)

2. Proxmox hardening
3. Docker + certificates (infrastructure hosts)
4. GitLab, Harbor, NetBox (individual hosts)
5. HAProxy (load balancers)
6. K8s prerequisites + GPU drivers
8. Certificate deployment (all cert-managed hosts)

## Adding a New Role

1. Create the role directory with standard structure:
   ```
   roles/new-role/
     defaults/main.yml   # Default variables
     tasks/main.yml      # Task list
     handlers/main.yml   # Service handlers (optional)
     templates/          # Jinja2 templates (optional)
     meta/main.yml       # Role metadata
     README.md           # Documentation
   ```
2. Add to `site.yml` with appropriate host group and tags
3. Add firewall ports to the relevant `group_vars/` file
4. Add sudo commands to the relevant `group_vars/` file
5. Update `scripts/ci-deploy-scope.sh` with the new role mapping
