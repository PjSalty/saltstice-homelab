# Roles Reference

## Security Roles

### common
Base OS configuration: packages, timezone, locale, sysctl hardening, chrony NTP, DNS resolvers.

**Tags**: `common`, `packages`, `timezone`, `sysctl`, `ntp`, `dns`

**Key Variables**:
- `common_packages`, Base packages to install
- `timezone`, System timezone (default: `America/Chicago`)
- `common_sysctl`, Kernel hardening parameters

### SSH
SSH server hardening via drop-in config at `/etc/ssh/sshd_config.d/99-hardening.conf`.

**Tags**: `ssh`, `config`

**Key Variables**:
- `ssh_port`, SSH port (default: 22)
- `ssh_permit_root_login`, Root login policy (default: `no`)
- `ssh_password_auth`, Password auth (default: `no`)

### firewall
UFW firewall with default deny incoming, per-group port allowlists.

**Tags**: `firewall`, `config`

**Key Variables**:
- `firewall_enabled`, Enable UFW (default: `true`)
- `firewall_default_incoming`, Default incoming policy (default: `deny`)
- `firewall_base_ports`, Ports open on all hosts
- `firewall_extra_ports`, Per-group additional ports

### fail2ban
Brute force protection with UFW integration.

**Tags**: `fail2ban`, `config`

**Key Variables**:
- `fail2ban_maxretry`, Max failures before ban (default: 5)
- `fail2ban_bantime`, Ban duration seconds (default: 3600)

### sudo
Minimal privilege sudoers configuration with per-group command allowlists.

**Tags**: `sudo`, `config`

### auto-updates
Unattended-upgrades for security patches.

**Tags**: `auto-updates`, `config`

### qemu-guest-agent
QEMU guest agent for Proxmox VM introspection.

**Tags**: `qemu-guest-agent`, `packages`

## Service Roles

### Docker
Docker CE from official Docker repository with daemon configuration.

**Tags**: `docker`, `packages`, `config`

**Key Variables**:
- `docker_users`, Users to add to Docker group
- `docker_registry_mirrors`, Registry mirror URLs

### HAProxy
HAProxy + keepalived HA pair for Kubernetes API load balancing.

**Tags**: `haproxy`, `config`

**Key Variables**:
- `haproxy_vip`, Virtual IP (default: `<internal-ip>`)
- `haproxy_role`, `MASTER` or `BACKUP`

### GitLab
GitLab CE deployment via Docker Compose.

**Tags**: `gitlab`, `config`

### Harbor
Harbor container registry via offline installer.

**Tags**: `harbor`, `config`

### Proxmox
Proxmox hypervisor hardening: IOMMU, kernel modules, GPU passthrough.

**Tags**: `proxmox`, `config`

### certificates
TLS certificate deployment from cert-manager to VMs.

**Tags**: `certificates`, `config`

## Specialty Roles

### K8s-prereqs
Kubernetes prerequisites: kernel modules, sysctl, swap disable, iSCSI, RKE2 manifests.

**Tags**: `k8s-prereqs`, `packages`, `kernel`, `sysctl`, `rke2`

### GPU
NVIDIA GPU driver and container toolkit installation.

**Tags**: `gpu`, `packages`, `config`, `verify`

### amp
CubeCoders AMP game server via Docker Compose.

**Tags**: `amp`, `config`

### vpn
WireGuard VPN via wg-easy Docker container.

**Tags**: `vpn`, `config`

### credential-rotation
SSOT-based credential lifecycle management.

**Tags**: `credentials`, `status`, `dry-run`, `rotate`, `generate`
