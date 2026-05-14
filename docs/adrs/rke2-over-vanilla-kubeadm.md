# ADR: RKE2 over vanilla kubeadm

**Status:** Accepted

## Context

Self-hosted Kubernetes on Proxmox VMs. Need a distribution.
Real options: RKE2, k3s, kubeadm-vanilla, Talos.

## Decision

RKE2 on Debian 13.

## Reasoning

Debian 13 stays the host OS. Talos was the other strong candidate
(immutable OS, K8s-native), but ruled out because the rest of the
homelab is Debian, same Ansible role library, same patching path,
same SSH workflow. Mixing two OSes for a one-cluster setup isn't
worth the operational cost.

That ruled out the option of "Talos cluster". RKE2 versus kubeadm versus
k3s, with Debian as the OS:

- **kubeadm**: full control, maximum operational surface. Every
 piece of glue is mine to maintain. For a one-operator homelab,
 too much rope.
- **k3s**: lightweight, fast, but the bundled SQLite or external
 etcd story for HA is awkward for a 3-master setup. Designed for
 edge and IoT.
- **RKE2**: K8s upstream binary inside a single systemd unit. CIS-hardened
 defaults. `system-default-registry` for Harbor proxy. CNI
 via HelmChartConfig (override the bundled Cilium values without
 fighting the installer). Single-binary upgrades via Ansible role.

RKE2 wins on the operational ergonomics for this scale.

## Bundled Cilium

RKE2 ships with Cilium as the default CNI. Override the bundled values
via `HelmChartConfig` in `kube-system`, same shape as a HelmRelease
but RKE2's own controller reads it. Drops kube-proxy, enables
BGP control plane, configures Hubble. See
[`infrastructure/cilium/`](../../infrastructure/cilium/) for the
actual config.

## Etcd in HAProxy

Three masters behind HAProxy + keepalived VIP. Workers hit the VIP for
the kube-apiserver. Loss of one master is invisible to workloads;
HAProxy reroutes. Keepalived handles VIP failover between the two
HAProxy VMs in case the primary HAProxy itself dies.

## What i gave up

Talos's immutability story. Worth real money in environments where
nodes get repaved frequently. In a homelab where i touch the OS via
Ansible weekly, the immutable model would be friction without
proportional benefit.

A vanilla kubeadm install. No problem to migrate to one if RKE2's
opinions ever fight me.

## When i would reconsider

- Edge device cluster → k3s is the right answer.
- Compliance requires immutable OS → Talos.
- Multi-cluster fleet at scale → vanilla kubeadm + Cluster API for
 the lifecycle abstraction.
