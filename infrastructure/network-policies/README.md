# Network Policies

CiliumNetworkPolicy and CiliumClusterwideNetworkPolicy definitions setting up zero-trust network segmentation across the cluster. Every namespace has explicit allow rules; all other traffic is denied by default.

Deployed by the `infrastructure-network-policies` Flux Kustomization, which depends on `infrastructure-configs` (ensuring Cilium and all controllers are running).

## Architecture

### Default Deny

`default-deny.yaml` defines a `CiliumClusterwideNetworkPolicy` that:

- Enables default deny for both ingress and egress on all pods
- Excludes system namespaces (`kube-system`, `kube-public`, `kube-node-lease`, `cilium-secrets`)
- Grants baseline egress to all pods:
 - DNS resolution to kube-DNS (port 53 UDP/TCP)
 - Kubernetes API server access (port 6443 TCP)

### Per-Namespace Policies

Each file in `namespaces/` defines a `CiliumNetworkPolicy` scoped to one namespace, explicitly allowing only the traffic that namespace needs. Policies follow the principle of least privilege.

## Namespace Policies

### Infrastructure Namespaces

| File | Namespace | Key Allows |
|------|-----------|------------|
| `flux-system.yaml` | Flux-system | Egress to GitLab (SSH), Helm repos (HTTPS), kube-apiserver |
| `cert-manager.yaml` | cert-manager | Egress to ACME servers, DNS for validation, kube-apiserver |
| `democratic-csi.yaml` | democratic-CSI | Egress to TrueNAS API (iSCSI), kubelet communication |
| `metallb-system.yaml` | MetalLB-system | BGP peering with MikroTik router (port 179), memberlist |
| `monitoring.yaml` | monitoring | Scrape targets across all namespaces, Grafana ingress, AlertManager to ntfy |
| `traefik.yaml` | Traefik | Ingress from all sources, egress to all service backends |
| `traefik-dmz.yaml` | Traefik-dmz | DMZ ingress, egress to DMZ service backends only |
| `kyverno.yaml` | Kyverno | Webhook ingress from API server, egress for policy checks |
| `loki.yaml` | loki | Ingress from Alloy log shippers, egress to NFS storage |
| `vpa.yaml` | vpa | kube-apiserver access for VPA controllers |
| `karpenter.yaml` | Karpenter | Egress to Proxmox API for node provisioning |
| `goldilocks.yaml` | Goldilocks | kube-apiserver access, ingress for dashboard |
| `external-dns.yaml` | external-DNS | Egress to AdGuard API |
| `vm-certificates.yaml` | vm-certificates | Egress to infrastructure VMs for cert deployment |
| `velero.yaml` | Velero | Egress to SeaweedFS S3 backend |
| `crowdsec.yaml` | crowdsec | Egress to CrowdSec API, Traefik bouncer communication |
| `falco.yaml` | Falco | Host network access for syscall monitoring |
| `reloader.yaml` | reloader | kube-apiserver access for ConfigMap/Secret watching |
| `external-secrets.yaml` | external-secrets | kube-apiserver access for Secret synchronization |
| `cluster-cleanup.yaml` | cluster-cleanup | kube-apiserver access for cleanup CronJob |
| `nvidia-device-plugin.yaml` | NVIDIA-device-plugin | kubelet communication for GPU scheduling |

### Application Namespaces

| File | Namespace | Key Allows |
|------|-----------|------------|
| `authentik.yaml` | Authentik | Ingress from Traefik + all namespaces (OIDC), egress to PostgreSQL, Redis, LDAP |
| `semaphore.yaml` | Semaphore | Ingress from Traefik, egress to GitLab, infrastructure VMs (Ansible) |
| `media.yaml` | media | Ingress from Traefik, egress to NFS (media files), TMDb API |
| `vaultwarden.yaml` | Vaultwarden | Ingress from Traefik, egress to PostgreSQL |
| `headlamp.yaml` | Headlamp | Ingress from Traefik, kube-apiserver for dashboard |
| `ntfy.yaml` | ntfy | Ingress from Traefik + AlertManager, egress to push notification services |
| `automation.yaml` | automation | Egress to Harbor/GitLab APIs, ntfy for notifications |
| `security.yaml` | security | Trivy scanner access to Harbor registry |
| `unifi.yaml` | UniFi | Ingress from Traefik + UniFi devices, STUN/inform ports |
| `amp.yaml` | amp | Ingress from Traefik, game server ports |
| `gitlab-runner.yaml` | GitLab-runner | Egress to GitLab API, Harbor registry, SeaweedFS cache |
| `vpn.yaml` | vpn | Ingress from Traefik for WireGuard web UI |
| `docmost.yaml` | Docmost | Ingress from Traefik, egress to PostgreSQL, Redis |
| `mcp-server.yaml` | mcp-server | Ingress from Traefik, egress to all infrastructure APIs (read-only MCP tools) |
| `fluxer.yaml` | fluxer | GitLab webhook ingress, egress to Flux API |

## Kustomization

```yaml
resources:
  - default-deny.yaml
  # Infrastructure namespace policies
  - namespaces/flux-system.yaml
  - namespaces/cert-manager.yaml
  # ... (36 namespace-specific policies)
```
