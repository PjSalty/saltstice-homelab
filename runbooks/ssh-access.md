# SSH Access Patterns

## Overview

SSH access in the Salty Homelab is **direct VM-to-VM** over the infrastructure VLAN. SSH traffic is NOT routed through Traefik or any load balancer by design.

## Architecture

```
                         ┌┐
   Internet                       Traefik             
   (HTTPS only) ►    (HTTP/HTTPS only)        
                           Ports: 80, 443             
                         ┘

   ┌┐
                       Infrastructure VLAN (<vlan-cidr>)        
                                                                 
      ┌┐    ┌┐    ┌┐    ┌┐ 
       GitLab       Harbor       NetBox       K8s      
       :22     ◄► :22     ◄► :22     ◄► Nodes    
      ┘    ┘    ┘    ┘ 
           ▲              ▲              ▲              ▲       
                                                            
           ┴┴┘       
                              SSH (Port 22)                     
                            Direct VM-to-VM                     
   ┘
                                    ▲
                                    
                         ┌┴┐
                            Admin Workstation 
                            (via VPN or LAN)  
                         ┘
```

## Why SSH is NOT Routed Through Traefik

1. **Protocol Incompatibility**: Traefik is an HTTP/HTTPS reverse proxy; SSH is a separate TCP protocol
2. **Security**: SSH should not be exposed to the internet; it's internal-only
3. **Performance**: Direct connections avoid unnecessary proxying overhead
4. **Simplicity**: Standard SSH client tools work without special configuration

## Access Methods

### From Local Network (LAN)

Connect directly to VM IP addresses:

```bash
# Example connections
ssh ansible@gitlab.example.com    # GitLab
ssh ansible@harbor.example.com    # Harbor
ssh ansible@netbox.example.com    # NetBox
ssh ansible@k8s-master-1                 # Kubernetes master
```

### From Remote (VPN Required)

1. Connect to WireGuard VPN (wg-easy at `vpn.example.com`)
2. Once connected, SSH as normal to internal IPs

```bash
# Connect to VPN first
wg-quick up wg0

# Then SSH
ssh ansible@<internal-ip>  # GitLab IP
```

### SSH Config Recommendations

Add to `~/.ssh/config`:

```
# Salty Homelab VMs
Host gitlab gitlab.example.com
    HostName <internal-ip>
    User ansible
    IdentityFile ~/.ssh/homelab_ed25519

Host harbor harbor.example.com
    HostName <internal-ip>
    User ansible
    IdentityFile ~/.ssh/homelab_ed25519

Host netbox netbox.example.com
    HostName <internal-ip>
    User ansible
    IdentityFile ~/.ssh/homelab_ed25519

Host k8s-master-*
    User ansible
    IdentityFile ~/.ssh/homelab_ed25519

Host k8s-worker-*
    User ansible
    IdentityFile ~/.ssh/homelab_ed25519

# Proxmox hypervisor
Host proxmox
    HostName <mgmt-ip>
    User root
    IdentityFile ~/.ssh/homelab_ed25519
```

## Authentication

### SSH Key (Primary Method)

All VMs are provisioned with the `ansible` user's SSH key via cloud-init:

- Key location (Terraform): `var.ssh_public_key`
- Key deployed to: `/home/ansible/.ssh/authorized_keys`

### Ansible Automation

Ansible connects via SSH using the same key:

```yaml
# ansible/inventory/hosts.yml
all:
  vars:
    ansible_user: ansible
    ansible_ssh_private_key_file: ~/.ssh/homelab_ed25519
```

## Security Considerations

1. **No Password Authentication**: SSH is key-only (PasswordAuthentication=no)
2. **No Root Login**: Direct root SSH is disabled (PermitRootLogin=no)
3. **Internal Only**: SSH port (22) is not exposed to internet
4. **VPN Required**: Remote access requires WireGuard VPN connection
5. **Firewall Rules**: Only management VLAN can reach SSH on infrastructure VMs

## Troubleshooting

### Cannot Connect via SSH

1. **Check network connectivity**:

   ```bash
   ping <internal-ip>
   ```

2. **Verify VPN is connected** (if remote):

   ```bash
   wg show
   ```

3. **Check SSH service on target**:

   ```bash
   # From another VM
   nc -zv <internal-ip> 22
   ```

4. **Check SSH key permissions**:

   ```bash
   ls -la ~/.ssh/homelab_ed25519
   # Should be: -rw------- (600)
   ```

### Connection Refused

- VM may not be running: Check Proxmox
- Firewall blocking: Check MikroTik firewall rules
- SSH service down: Restart via Proxmox console

### Authentication Failed

- Wrong key: Verify correct key in `~/.ssh/config`
- Key not deployed: Re-run Ansible base configuration
- User doesn't exist: Check cloud-init completed

## Related Files

| File | Purpose |
|------|---------|
| `terraform/variables.tf` | `ssh_public_key` variable |
| `ansible/inventory/hosts.yml` | SSH connection settings |
| `ansible/roles/base/tasks/ssh.yml` | SSH hardening configuration |
