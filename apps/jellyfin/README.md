# Jellyfin

Single-replica Deployment, NVIDIA RTX A2000 hardware transcoding (NVENC),
iSCSI block storage for config/cache, NFS read-only mount for media,
RAM-backed tmpfs for transcode scratch, Authentik OIDC SSO via the SSO-Auth
plugin, dual-host ingress (LAN + WAN), Cilium NetworkPolicy.

Version: 10.11.6.

## Why this is non-trivial

### NVIDIA hardware transcoding

The RTX A2000 is passed through to one Kubernetes worker via Proxmox PCIe
passthrough. On the K8s side:

- `nvidia-device-plugin` exposes `nvidia.com/gpu` and registers an
 `nvidia` RuntimeClass.
- The pod spec sets `runtimeClassName: nvidia` and a nodeSelector
 `nvidia.com/gpu.present: "true"`.
- Container env: `NVIDIA_VISIBLE_DEVICES=all` and
 `NVIDIA_DRIVER_CAPABILITIES=all` so NVENC encode + CUVID decode show
 up in Jellyfin's HW accel options.

Single GPU = single replica (`strategy: Recreate`). Restoring the GPU
node is the only recovery path; no relocation possible.

### iSCSI for config, NFS for media

`jellyfin-config-iscsi` (30Gi, RWO, iSCSI block) holds the SQLite
database. Originally on NFS, caused file-locking issues and UI lag.
Block storage solved both. Cache is also iSCSI so artwork survives
pod restarts (1300+ items would otherwise re-download every time).

Media is NFS read-only. ~50TiB. Mount options tuned for streaming:
`nfsvers=4.1`, 1MB R/W blocks, `actimeo=3600`, `noatime`. Read-only
because organize is a separate Deployment (`media-drop-watcher`)
running with write access on a different mount.

### `.NET` file locking off

`DOTNET_SYSTEM_IO_DISABLEFILELOCKING=true`. NFS/iSCSI file locking
semantics fight Jellyfin's .NET runtime; disabling app-level locking
matches the storage-layer behavior and stops intermittent lock
errors during library scans.

### LAN/WAN URL handling

`JELLYFIN_PublishedServerUrl` is set to a publicly-resolvable host.
LAN clients auto-switch to the local address via Jellyfin's discovery
broadcast; mobile/WAN clients use the published URL. Without this
setting, Firestick and iOS hit `LocalAddress` from the announce, fail,
and surface "no server found."

### Authentik SSO via init-container plugin install

The SSO-Auth Jellyfin plugin v4.0.0.3 is installed by an init container
that runs on every pod start. It downloads the plugin DLL if missing
and templates the OIDC config XML on every restart so the
`AdminRoles` mapping (`jellyfin-admins` group from Authentik) is
always current. Client secret comes from a Kubernetes Secret;
plaintext never touches the manifest.

External users still sign in with local Jellyfin accounts because
`auth.example.com` (Authentik) has no public DNS record.

### Recreate strategy + RWO PVCs

iSCSI volumes are RWO. With one GPU node the deployment can't roll.
`strategy: Recreate` formalizes that. Streams interrupt briefly during
restart, which is acceptable given the workload.

## Layout

```
jellyfin/
├── README.md
├── kustomization.yaml
├── namespace.yaml
├── deployments/deployment.yaml        , Pod spec, NVIDIA runtime, init SSO install
├── services/service.yaml              , LoadBalancer (8096 + 7359/UDP)
├── ingress/ingress.yaml               , Dual-host: LAN + WAN
├── networkpolicy/cilium-networkpolicy.yaml, Zero-trust egress allow-list
├── autoscaling/vpa.yaml               , VPA Auto for jellyfin + media-drop-watcher
├── storage/storage.yaml               , iSCSI PVCs + 50Ti NFS PV
└── pdb/pdb.yaml                       , maxUnavailable: 1, excludes Job pods
```

## Required Secrets

| Secret | Keys | Purpose |
|---|---|---|
| `jellyfin-admin-credentials` | `OIDC_CLIENT_SECRET` | Jellyfin SSO client secret |
| `sso-client-secrets` | `JELLYFIN_CLIENT_SECRET` | Used by init container |

## Required Substitution Variables

| Var | Source |
|---|---|
| `${IMAGE_JELLYFIN}` | image-versions ConfigMap |
| `${IMAGE_ALPINE}` | image-versions ConfigMap |
| `${JELLYFIN_LB_IP}` | network-config ConfigMap (MetalLB pool address) |
| `${TRAEFIK_LB_IP}` | network-config ConfigMap |
| `${NFS_SERVER}` | network-config ConfigMap |
| `${STORAGE_CIDR}` | network-config ConfigMap (storage VLAN range) |

## Dependencies

- NVIDIA GPU node with `nvidia.com/gpu.present` label and `nvidia` RuntimeClass
- `nvidia-device-plugin` DaemonSet
- democratic-CSI (iSCSI driver) for config/cache
- NAS NFS server for media
- MetalLB for LoadBalancer IPs
- Traefik ingress controller + wildcard cert
- Authentik (OIDC provider with `jellyfin-sso` application)
- Router NAT rule for external access
- Cloudflare-DNS-sync CronJob for the public A record
