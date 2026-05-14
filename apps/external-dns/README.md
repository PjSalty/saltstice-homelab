# External-DNS

External-DNS automates DNS record management across three DNS providers: AdGuard Home (internal), Cloudflare (public), and NetBox (source of truth). It implements bidirectional DNS synchronization per Guardian Principle 3.

## Architecture

The system has four components:

1. **External-DNS Deployment** -- Watches K8s Ingress/IngressRoute/Service resources and syncs DNS records to AdGuard via a webhook sidecar
2. **Cloudflare DNS Sync CronJob** -- Manages public A records in Cloudflare for services labeled `dns.example.com/public=true`
3. **K8s-to-NetBox Sync CronJob** -- Syncs Ingress/IngressRoute hostnames to NetBox IP objects (K8s informs NetBox)
4. **NetBox-to-AdGuard Sync CronJob** -- Syncs NetBox IP objects with `dns_name` to AdGuard DNS rewrites

DNS Flow:
```
K8s Ingress/IngressRoute --> External-DNS --> AdGuard (internal)
K8s Ingress/IngressRoute --> k8s-to-netbox-sync --> NetBox (SSOT)
NetBox --> netbox-dns-sync --> AdGuard (internal)
K8s labels --> cloudflare-dns-sync --> Cloudflare (public)
```

- **Namespace**: `external-dns`
- **External-DNS Version**: v0.18.0
- **AdGuard Webhook Version**: v9.1.0

## Directory Structure

```
external-dns/
  kustomization.yaml
  base/
    kustomization.yaml
    namespace.yaml
    autoscaling/
      kustomization.yaml
      vpa.yaml
    configmaps/
      cloudflare-dns-state.yaml
    cronjobs/
      cloudflare-dns-sync.yaml
      k8s-to-netbox-sync.yaml
      netbox-dns-sync.yaml
    deployments/
      deployment.yaml
    pdb/
      pdb.yaml
    rbac/
      clusterrole.yaml
      clusterrolebinding.yaml
      serviceaccount.yaml
```

## File Descriptions

### `kustomization.yaml`

Top-level Kustomization that references `base/`.

### `base/kustomization.yaml`

Assembles all base resources including namespace, RBAC, deployment, CronJobs, autoscaling, and PDB.

### `base/namespace.yaml`

Creates the `external-dns` namespace with Goldilocks enabled.

### `base/deployments/deployment.yaml`

External-DNS Deployment with two containers:

**external-DNS container**:
- Image: `${IMAGE_EXTERNAL_DNS}` (v0.18.0)
- Sources: ingress, service, Traefik-proxy
- Domain filter: `example.com`
- Provider: webhook (connects to sidecar at localhost:8888)
- Sync policy with TXT registry (owner: `external-dns-homelab`, prefix: `_external-dns.`)
- 1-minute sync interval
- Runs as non-root (UID 65534), read-only filesystem

**AdGuard-webhook sidecar**:
- Image: `${IMAGE_ADGUARD_PROVIDER}` (v9.1.0)
- Connects to AdGuard using credentials from `adguard-credentials` secret
- Sets important flag on DNS rules
- Health check on port 8080
- Runs as non-root (UID 65534), read-only filesystem

### `base/rbac/`

RBAC configuration:
- **ServiceAccount**: `external-dns`
- **ClusterRole**: Read access to services, endpoints, pods, endpointslices, ingresses, nodes, Traefik CRDs (IngressRoute, IngressRouteTCP, IngressRouteUDP), and patch access to `cloudflare-dns-state` ConfigMap
- **ClusterRoleBinding**: Binds the ClusterRole to the ServiceAccount

### `base/cronjobs/cloudflare-dns-sync.yaml`

Public DNS management via Cloudflare API:
- **Schedule**: Every 5 minutes
- Scans K8s Ingress/IngressRoute for `dns.example.com/public=true` label
- Gets current WAN IP via `api.ipify.org`
- Creates/updates/deletes Cloudflare A records tagged with `managed-by:public-dns-sync`
- Supports annotations:
 - `dns.example.com/proxied: "true"` -- enable Cloudflare proxy (hide WAN IP)
 - `dns.example.com/public-hostname: "x.com"` -- override hostname for public DNS
- Updates `cloudflare-dns-state` ConfigMap with sync state
- Credentials from `cloudflare-api-token` Secret

### `base/cronjobs/k8s-to-netbox-sync.yaml`

K8s to NetBox DNS sync (Principle 3: Bidirectional Synchronization):
- **Schedule**: Every 10 minutes
- Scans K8s Ingress and IngressRoute for `example.com` hostnames
- Creates IP address objects in NetBox with `dns_name` set
- Uses Traefik VIP (`${TRAEFIK_LB_IP}`) as the IP for all records
- Credentials from `netbox-credentials` Secret

### `base/cronjobs/netbox-dns-sync.yaml`

NetBox to AdGuard DNS sync:
- **Schedule**: Every 15 minutes
- Fetches all IPs with `dns_name` from NetBox
- Syncs to AdGuard DNS rewrites (add/update)
- Skips domains managed by external-DNS deployment (GitLab, Harbor, NetBox, TrueNAS, Proxmox, AdGuard)
- Credentials from `netbox-credentials` and `adguard-credentials` Secrets

### `base/configmaps/cloudflare-dns-state.yaml`

State tracking ConfigMap for Cloudflare sync:
- `last-wan-ip` -- Last known WAN IP
- `last-sync` -- Timestamp of last sync
- `managed-records` -- JSON list of managed hostnames

### `base/pdb/pdb.yaml`

PodDisruptionBudget with `minAvailable: 1` for external-DNS.

### `base/autoscaling/vpa.yaml`

VPA (Auto mode) for the external-DNS Deployment with policies for both containers:
- **external-DNS**: CPU 10m-250m, memory 32Mi-256Mi
- **AdGuard-webhook**: CPU 10m-100m, memory 32Mi-128Mi

## Secrets

| Secret Name | Keys | Purpose |
|---|---|---|
| `adguard-credentials` | `ADGUARD_URL`, `ADGUARD_USER`, `ADGUARD_PASSWORD` | AdGuard Home API access |
| `cloudflare-api-token` | `CF_API_TOKEN`, `CF_ZONE_NAME` | Cloudflare DNS API |
| `netbox-credentials` | `NETBOX_URL`, `NETBOX_TOKEN` | NetBox API access |

## Dependencies

- AdGuard Home DNS server
- Cloudflare DNS zone (example.com)
- NetBox IPAM (source of truth)
- Traefik IngressRoute CRDs
- External internet access (for WAN IP detection and Cloudflare API)
