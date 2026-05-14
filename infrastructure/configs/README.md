# Infrastructure Configs

Post-install configuration resources that depend on infrastructure controllers being healthy. These define how controllers behave: IP address pools, certificate issuers, ingress middlewares, SSOT variables, ExternalSecret mappings, PodDisruptionBudgets, and backup schedules.

Deployed by the `infrastructure-configs` Flux Kustomization, which depends on `infrastructure-controllers`.

## Directories

### ssot/ -- Single Source of Truth ConfigMaps

Central configuration that all Flux Kustomizations reference via `postBuild.substituteFrom`:

| File | Resource | Purpose |
|------|----------|---------|
| `image-versions.yaml` | ConfigMap `image-versions` | All pinned image tags (`${IMAGE_PROMETHEUS}`) and Helm chart versions (`${HELM_TRAEFIK}`). Auto-generated from `config/versions.yaml`. |
| `network-config.yaml` | ConfigMap `network-config` | IP addresses, NFS paths, domain name, VLAN assignments. Auto-generated from `config/network.yaml`. |

These ConfigMaps live in the `flux-system` namespace and are referenced by every Kustomization's `postBuild` block, enabling `${VARIABLE}` substitution in all manifests.

### cert-manager/ -- Certificate Issuers and Wildcard Certificate

| File | Resource | Purpose |
|------|----------|---------|
| `cluster-issuer.yaml` | ClusterIssuer `letsencrypt-prod`, `letsencrypt-staging`, `selfsigned` | Let's Encrypt issuers using DNS-01 via acme-DNS delegation (ISP blocks port 80) |
| `wildcard-certificate.yaml` | Certificate `wildcard-tls` | Wildcard cert for `*.example.com` and `*.example.com`, replicated to all namespaces by Kyverno policy |

### MetalLB/ -- Load Balancer Configuration

| File | Resource | Purpose |
|------|----------|---------|
| `ipaddresspool.yaml` | IPAddressPool `default-pool` | VLAN 50 (<internal-ip>-149) for internal application LoadBalancers |
| `dmz-pool.yaml` | IPAddressPool `dmz-pool` | VLAN 60 (<internal-ip>-110) for DMZ/community services |
| `bgppeer.yaml` | BGPPeer `mikrotik-peer` | BGP session with MikroTik router (ASN <asn> <-> <asn>) on VLAN 30 gateway |
| `bgpadvertisement.yaml` | BGPAdvertisement `homelab-bgp` | Advertises internal pool IPs as /32 routes via BGP |
| `l2advertisement.yaml` | L2Advertisement `homelab-l2` | L2 fallback for default pool on eth0 |

### Traefik/ -- Ingress Middlewares, TLS, and External Services

| File | Resource | Purpose |
|------|----------|---------|
| `middlewares.yaml` | Middleware `https-redirect`, `security-headers`, `proxmox-security-headers` | HTTPS redirect, security headers (HSTS, CSP, X-Frame-Options) |
| `tls-options.yaml` | TLSOption `default` | TLS 1.2+ enforcement with strong cipher suites, SNI strict mode |
| `external-services-auth.yaml` | Endpoints, Service, IngressRoute for TrueNAS and AdGuard | Proxies external VM services through Traefik with optional Authentik forward-auth |
| `unifi-tls-certificate.yaml` | Certificate `unifi-tls` | Dedicated TLS cert for UniFi controller |

### coredns/ -- Split-Horizon DNS

| File | Resource | Purpose |
|------|----------|---------|
| `helmchartconfig.yaml` | HelmChartConfig `rke2-coredns` | RKE2 CoreDNS override setting up split-horizon DNS: `example.com` zone resolves internally via hosts plugin + AdGuard forward, never leaking to public DNS |

### external-secrets/ -- Credential Distribution via ESO

| File | Resource | Purpose |
|------|----------|---------|
| `rbac.yaml` | ServiceAccounts, Roles, RoleBindings per namespace | Grants ESO store service accounts read access to `cred-ssot-core` Secret in Flux-system |
| `secretstores.yaml` | SecretStore `credential-core` per namespace | Namespace-scoped SecretStores pointing to the SOPS-decrypted source Secret in Flux-system |
| `externalsecrets/` | ExternalSecret per application | Maps specific credential fields from the source Secret into per-namespace target Secrets |

The ExternalSecrets directory contains one file per application (Authentik, Docmost, monitoring, etc.), each defining which credential keys to extract and which Kubernetes Secret to create.

### PDB/ -- PodDisruptionBudgets

| File | Resource | Purpose |
|------|----------|---------|
| `coredns-pdb.yaml` | PDB `coredns-pdb` | Makes sure at least 1 CoreDNS pod remains available during disruptions |
| `ingress-nginx-pdb.yaml` | PDB `ingress-nginx-pdb` | Limits RKE2 ingress-nginx controller disruption to 1 pod at a time |

### Velero/ -- Backup Schedules

| File | Resource | Purpose |
|------|----------|---------|
| `schedules.yaml` | Schedule `daily-full`, `hourly-stateful` | Daily full backup (2am, 3-day retention) of stateful namespaces; hourly PVC/Secret backup (48h retention) for critical apps |

## Kustomization

```yaml
resources:
  - ssot
  - metallb
  - traefik
  - cert-manager
  - coredns
  - velero
  - pdb
  - external-secrets
```
