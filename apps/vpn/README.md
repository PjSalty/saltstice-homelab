# VPN

Kubernetes ingress proxy for the wg-easy WireGuard VPN server, which runs on an external VM in the DMZ (VLAN 60). This namespace does not run any pods -- it only provides Traefik HTTPS access to the external VM.

## FQDN

`https://vpn.example.com`

## Namespace

`vpn`

## Directory Structure

```
base/
  kustomization.yaml       - Kustomize manifest listing all resources
  namespace.yaml           - Namespace definition (DMZ VLAN 60 annotation)
  service.yaml             - Headless Service + manual Endpoints pointing to VPN VM
  ingressroute.yaml        - Traefik IngressRoutes (HTTPS + HTTP redirect)
```

## Architecture

The wg-easy WireGuard VPN server runs on a dedicated VM at `<internal-ip>` (DMZ VLAN 60), not inside Kubernetes. This namespace creates a Kubernetes Service with manual Endpoints to proxy traffic from Traefik to the external VM.

```
Client -> Traefik (<internal-ip>)
       -> Service/wg-easy (vpn namespace)
       -> Endpoints (<internal-ip>:51821)
       -> wg-easy VM (DMZ VLAN 60)
```

## Key Configuration

### Service + Endpoints

The Service has no selector (headless external service). Manual Endpoints point to the VPN VM:
- **IP**: `<internal-ip>` (DMZ VLAN 60)
- **Port**: 51821 (wg-easy web UI)

### IngressRoute

Two Traefik IngressRoutes:

**HTTPS (websecure)**:
- Host: `vpn.example.com`
- TLS termination with `wildcard-tls`
- Security headers middleware
- Proxies to wg-easy port 51821 with `passHostHeader: true`

**HTTP redirect (web)**:
- Redirects HTTP to HTTPS via `https-redirect` middleware

## Secrets

No secrets are managed in this namespace. The wg-easy VM handles its own WireGuard configuration.

## Dependencies

- wg-easy VM at <internal-ip> (external, managed by Ansible)
- Traefik (HTTPS termination and routing)
- Wildcard TLS certificate (`wildcard-tls`)
