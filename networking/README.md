# networking

## Hardware

| Device | Role |
|---|---|
| MikroTik RB4011 | edge router, BGP, firewall, DHCP, DNS forwarder |
| MikroTik CRS317 | 10G aggregation |
| MikroTik CRS328 | PoE access |
| HAProxy + keepalived (VMs) | K8s API VIP failover |

## VLANs

| VLAN | Use |
|---|---|
| mgmt | network device management |
| infra | infra VMs (GitLab, Harbor, NetBox, AdGuard, HAProxy) |
| K8s | K8s nodes + pods |
| storage | NFS / iSCSI |
| services | MetalLB pool |

## BGP

Cilium BGP control-plane peers directly with the RB4011 over unnumbered
BGP with MD5 auth. Cilium advertises pod CIDRs and `/32`s for each
MetalLB-allocated service IP. Router installs them, LAN clients reach
Traefik (and other LBs) without an extra NAT.

## Cilium config that matters

```yaml
kubeProxyReplacement: true
routingMode: native
autoDirectNodeRoutes: true
loadBalancer:
  mode: dsr
  algorithm: maglev
bpf:
  masquerade: true
hostFirewall:
  enabled: true
hubble:
  metrics:
    enabled: [dns, drop, tcp, flow, icmp, http]
```

## DNS

- Internal: AdGuard on a VM (two replicas, kept in sync). Resolves
 `*.example.com` to the Traefik VIP.
- External: Cloudflare. Carries only the public-facing services
 (Jellyfin and the apex). A K8s CronJob keeps the WAN A records
 current with the dynamic ISP IP.

## External access

ISP blocks port 80, so public services use a non-standard port:
`jellyfin.example.com:<external-port>` NATed by MikroTik to the Traefik VIP on
`:443`. Cloudflare DNS is grey-cloud (DNS-only).

Internal-only services have no public DNS at all. Access from outside
goes through WireGuard.

## Firewall layers

1. MikroTik edge, drops everything inbound except WAN-NATed service
 ports; default-deny on VLAN-to-VLAN, explicit allow lists.
2. Proxmox cluster firewall, host-level on the bridge.
3. UFW on every VM, default-deny FORWARD, explicit allow for
 `vmbr+ → vmbr+` (see incident write-up below).

The interaction matters. See
[`incidents/2026-03-17-bridge-nf-ufw-proxmox.md`](../incidents/2026-03-17-bridge-nf-ufw-proxmox.md)
for what happens when these layers misalign.
