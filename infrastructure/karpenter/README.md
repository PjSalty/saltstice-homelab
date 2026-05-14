# Karpenter

Kubernetes node autoscaling on Proxmox. Deploys two Flux Kustomizations:
`karpenter` (HelmRelease + namespace + cloud-init template) and
`karpenter-config` (NodePool + NodeClass, depends on the first for CRDs).

Provider: [`sergelogvinov/karpenter-provider-proxmox`](https://github.com/sergelogvinov/karpenter-provider-proxmox).
Chart v0.4.4, app v0.9.0.

## Layout

```
karpenter/
├── kustomization.yaml        , namespace + helmrelease + cloud-init template + autoscaling
├── namespace.yaml            , baseline PSA
├── helmrelease.yaml          , Karpenter Proxmox provider
├── cloud-init-template.yaml  , Cloud-init for new node provisioning
├── autoscaling/
│   └── vpa.yaml              , VPA Auto for the controller
└── config/
    ├── kustomization.yaml
    └── nodepool.yaml         , NodePool + NodeClass + ProxmoxUnmanagedTemplate
```

## NodePools

Three pools at different vCPU:memory ratios. Karpenter picks the pool whose
ratio best fits each pending pod's `requests`. Weight breaks ties.

| Pool | vCPU:Mem | Limits | Weight | Consolidate | Expire | Family |
|---|---|---|---|---|---|---|
| `standard-pool` | 1:4 | 16 CPU / 64Gi | 50 | 10m | 720h (30d) | s1 |
| `memory-pool` | 1:8 | 8 CPU / 64Gi | 30 | 15m | 720h (30d) | m1 |
| `compute-pool` | 1:2 | 16 CPU / 32Gi | 20 | 5m | 168h (7d) | c1 |

`compute-pool` is intentionally the most aggressive: 5-minute consolidation
matches CI runner load patterns (build, idle, gone).

All pools share a `homelab.example.com/karpenter=true:NoSchedule` taint so
non-autoscaled workloads (DaemonSets, Flux controllers) won't accidentally
land on transient nodes.

`expireAfter` is the rotation knob, every node gets recycled at that
interval to pick up OS patches.

## ProxmoxNodeClass

Single NodeClass `debian-worker` referencing a pre-existing Proxmox VM
template (Debian 13, cloud-init-ready, QEMU guest agent). The template is
built by an Ansible playbook against a fresh Debian image; rebuild the
template after any base-image change or new nodes provision with stale OS.

```yaml
spec:
  region: homelab
  bootDevice:
    size: 50Gi
    storage: local-zfs
  metadataOptions:
    type: cdrom
    templatesRef: { name: karpenter-cloud-init, namespace: karpenter }
    valuesRef:    { name: karpenter-cloud-init-values, namespace: karpenter }
```

## Proxmox API access

API token `automation@pam!karpenter` with a custom `Karpenter` role
(privilege separation off). Token in a SOPS-encrypted secret;
Flux decrypts at reconciliation. Token never enters TF state, provider
reads it from the K8s secret on startup.

## Drain behavior

When Karpenter retires a node (consolidation or expiry), it cordons,
drains, and waits for evictions. PDBs honored. The Proxmox provider
then issues `qm shutdown` followed by `qm destroy` after a grace
period. If a pod hangs the drain (PDB violation, finalizer stuck),
the node won't be removed; investigate the pod, don't delete the
node by hand.

## Required alerts

- `KarpenterNodeProvisioningFailed`, pending NodeClaims that can't be
 satisfied (ratio mismatch, pool at limit, Proxmox host full)
- `KarpenterNodeDrainStalled`, nodes Cordoned for >15 min

## ADR

[`docs/adrs/0004-karpenter-over-cluster-autoscaler.md`](../../docs/adrs/0004-karpenter-over-cluster-autoscaler.md)
