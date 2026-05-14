# ADR: Cilium for the CNI

**Status:** Accepted

## Context

Single Kubernetes cluster on Proxmox VMs. Need a CNI that handles
NetworkPolicy, can BGP-peer with the MikroTik edge router for
MetalLB advertisement, and has visibility into pod-to-pod traffic.

Two adults: Cilium and Calico.

## Decision

Cilium with kube-proxy replacement and BGP control plane.

## Reasoning

EBPF datapath as the primary mode. Cilium's policy enforcement and LB
live in BPF maps, not iptables chains. At the policy density planned
here (40+ CNPs), iptables rule expansion becomes a real cost.
Calico can do eBPF too, but it's an opt-in mode with lower coverage.

Hubble for free. Flow-level visibility into every connection without
running a separate mesh. `hubble observe` is the troubleshooting
default; iptables-counter approximation isn't.

BGP control plane in Cilium 1.x+. Peers directly with the MikroTik
RB4011 with MD5 auth. Advertises pod CIDRs and `/32`s for each
MetalLB-allocated service IP. No bird, no Calico-BGP, no extra daemons.

Kube-proxy replacement. Service VIPs live in BPF maps. Drops a
DaemonSet, drops iptables-chain bloat, makes Service routing visible
in `hubble observe`.

Identity-based policy. Endpoints get a security identity derived from
labels; policies are written in identity terms, not IPs. Pod IPs churn,
identity stays stable, policy doesn't break on restart.

## What i gave up

Mature Windows support. Calico is the choice if any Windows nodes
exist. None here.

A stable iptables fallback. When the eBPF datapath fails (it has.
see the silent-degradation incident), there's no familiar fallback to
retreat to.

## The trap that bit

Cilium 1.x's liveness probe is hardcoded with `brief=true` and
`require-k8s-connectivity=false`. Process passes the probe while the
datapath is broken. Required mitigation: outcome-based alerts
(drop rate, endpoint regeneration failures, identity cache size,
BPF map pressure) instead of trusting the probe. Six rules now in
`monitoring/prometheus/`.

If you adopt Cilium, ship those alerts on day one.

## When i would reconsider

- Multi-cluster fleet → ClusterMesh adds value, but also adds blast
 radius. Worth a re-evaluation.
- Windows nodes appear → Calico for those, hybrid is supported but
 ugly.
- A Cilium upstream regression that lasts more than a release →
 iptables Calico is the bedrock to retreat to.
