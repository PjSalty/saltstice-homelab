# ADR: Karpenter (Proxmox provider) over Cluster Autoscaler

**Status:** Accepted

## Context

Spiky workloads, batch media organize jobs, periodic CI runners,
occasional rebuilds. Static node count was over-provisioned at idle
or under-provisioned at peak. Wanted node-level autoscaling.

Cluster Autoscaler exists. Karpenter is newer.

## Decision

Karpenter with the community Proxmox provider. Three weighted
NodePools at different vCPU:memory ratios.

## Reasoning

Bin-packing per pod, not per node-group. Cluster Autoscaler picks a
predefined node group. A pending pod that wants 16Gi/2 CPU triggers a
"memory" group node, even when a 1:2 ratio node would be cheaper and
faster. Karpenter looks at actual pod requirements every cycle and
provisions the cheapest node that satisfies them.

Three pools at non-overlapping ratios:

| Pool | vCPU:Memory | Limits | Weight | Consolidate | Expire |
|---|---|---|---|---|---|
| `standard-pool` | 1:4 | 16 / 64Gi | 50 | 10m | 720h (30d) |
| `memory-pool` | 1:8 | 8 / 64Gi | 30 | 15m | 720h (30d) |
| `compute-pool` | 1:2 | 16 / 32Gi | 20 | 5m | 168h (7d) |

`compute-pool` consolidation is intentionally aggressive: CI runners
build, idle, get torn down. Five-minute window matches the workload.
`expireAfter` is the rotation knob, every node recycled at that
interval picks up OS patches.

Self-hosted Proxmox provider. `sergelogvinov/karpenter-provider-proxmox`
is alpha, single-maintainer. Real risk. Picked anyway because:

- Interface is small (clone Proxmox VM template, register with K8s,
 drain and delete on removal). Easy to read, easy to debug.
- Cluster Autoscaler with manually-curated Proxmox node groups was
 also going to be brittle.
- One operator. If the provider stops, rebuild on CA in a weekend.

## What i gave up

Cloud-provider battle-tested code paths. Karpenter's AWS / Azure / GCP
providers are mature; Proxmox isn't.

Stack Overflow answers. Most homelab Proxmox autoscaling questions
don't exist online yet. Reading source is the first option, not the
last.

## When i would reconsider

- Provider abandons → rebuild on Cluster Autoscaler with three node
 groups (one per pool). Slightly worse bin-packing, identical
 interface for the rest of the cluster.
- Move to managed K8s → Karpenter cloud providers are the right
 default, this ADR doesn't apply.
- Workload mix flattens → static node count is fine, no autoscaler
 needed.
