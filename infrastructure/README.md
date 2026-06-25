# infrastructure

Cluster-wide concerns. Anything not specific to a single application.

## Inventory

| Path | What |
|---|---|
| `cilium/` | CNI HelmChartConfig, BGP peering policy, kube-proxy replacement, Hubble |
| `cert-manager/` | ACME issuers, wildcard cert via DNS-01 + acme-DNS delegation |
| `controllers/traefik/` | ingress controller, ConfigMap-driven values |
| `controllers/velero/` | backup with Kopia + SeaweedFS S3 |
| `controllers/falco/` | runtime security, modern eBPF, Falcosidekick |
| `truenas-csi/` | official iX CSI driver (`csi.truenas.io`), iSCSI + NFS against TrueNAS over WebSocket JSON-RPC |
| `karpenter/` | node autoscaling on Proxmox |
| `loki/`, `tempo/` | log + trace backends, S3-backed |
| `network-policies/` | cluster-wide default-deny + per-namespace policies |
| `psa-labels/` | Pod Security Admission per namespace |
| `rbac/` | non-app cluster roles |
| `resource-quotas/` | per-namespace quotas (where applied) |
| `sources/` | Flux GitRepositories + HelmRepositories |
| `storage/` | StorageClasses, base PV definitions |
| `tls-certificates/` | wildcard cert + Kyverno cross-namespace replication |
| `configs/` | SSOT ConfigMaps (image-versions, network-config) consumed via `postBuild.substituteFrom` |

## SSOT pattern

Two ConfigMaps act as substitution sources for every Flux Kustomization:

- `image-versions.yaml`, every container image tag in one place
- `network-config.yaml`, every static IP, VLAN, CIDR

Manifests reference `${IMAGE_AUTHENTIK}`, `${TRAEFIK_LB_IP}`, etc.
Flux substitutes at reconciliation time. Bumping a version touches
one ConfigMap. Renovate updates that ConfigMap automatically.

## Multi-source Flux

```
GitRepository: flux-system   → apps repo (this one)
GitRepository: secrets       → SOPS-encrypted secrets repo (separate)
HelmRepository: ...          → upstream chart sources
```

Every app `Kustomization` has `dependsOn: [secrets]`. Secret rotation
doesn't trigger app reconciles unless an app's secret actually
changed, because ESO is the layer that propagates them in.

## cert-manager

`letsencrypt-prod` ClusterIssuer using DNS-01 via acme-DNS delegation.
The ISP blocks port 80, so HTTP-01 isn't viable for the primary
wildcard. Acme-DNS runs on a separate VM, holds the actual TXT records,
and delegates challenge resolution to itself via CNAME from the real
domain. Wildcard cert gets renewed automatically; replicated
cluster-wide via Kyverno `sync-wildcard-tls` so any namespace can
reference it.

## Order of bring-up

Documented in `clusters/homelab/infrastructure-kustomizations.yaml`
via `dependsOn`:

1. Flux-system controllers
2. CRDs (cert-manager, Prometheus operator, Cilium policies)
3. Secrets
4. Cert-manager + wildcard cert
5. Cilium (already present pre-Flux, but managed for upgrades)
6. Traefik
7. Authentik
8. Everything else
