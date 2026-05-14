# qemu-guest-agent

Installs and enables the QEMU guest agent on Proxmox VMs. Provides VM introspection capabilities (IP reporting, graceful shutdown, filesystem freeze) to the hypervisor.

## Tasks (tasks/main.yml)

1. Install qemu-guest-agent package (skipped on Proxmox host itself)
2. Enable and start the qemu-guest-agent service

## Variables (defaults/main.yml)

| Variable | Default | Description |
|----------|---------|-------------|
| `qemu_guest_agent_enabled` | `true` | Enable the guest agent service |

## Notes

- Skipped on hosts in the `proxmox` group (the hypervisor does not need the guest agent)
- Requires `agent: 1` in the Proxmox VM options and a VM reboot for the virtio device to appear

## Tags

`qemu-guest-agent`, `packages`
