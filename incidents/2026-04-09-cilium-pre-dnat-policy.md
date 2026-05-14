# Cilium policy evaluation order: why your port 443 rule blocks port 6443

**Date:** 2026-04-09
**Impact:** Three cluster-wide outages in one session as pods couldn't reach `kube-apiserver`.

## Summary

Pods that needed to talk to the Kubernetes API server kept getting blocked by
CiliumNetworkPolicies that allowed port 6443. The policies were "correct", the
API server listens on 6443, but Cilium evaluated them *before* kube-proxy DNAT,
so the destination port being checked was 443 (the ClusterIP), not 6443 (the
node port behind it).

Three cluster outages happened in one debugging session because every "fix" to
the policy assumed Cilium evaluated rules post-DNAT. It doesn't.

## Symptoms

- `kubectl` from inside a pod times out.
- Operators (Flux, ESO, cert-manager) log "no route to kube-apiserver" or
 "connection refused on 443."
- `cilium policy trace` shows a DENY on `:443 → DENY ALL`.
- The policy explicitly allows `:6443`. Confused.

## Root cause

When a pod connects to `kubernetes.default.svc.cluster.local`, the destination
resolves to the ClusterIP `10.43.0.1:443`. Cilium's policy engine evaluates the
egress rule **at the moment the packet leaves the pod**, before kube-proxy (or
Cilium's BPF replacement) translates that ClusterIP to the actual node IP and
port (`<node-ip>:6443`).

So Cilium sees a packet headed for `:443` and your policy says `:6443` is
allowed. No match. Drop.

## Fix

The egress policy must allow **both** ports, 6443 (for direct node-IP
connections) and 443 (for the pre-DNAT ClusterIP path):

```yaml
apiVersion: cilium.io/v2
kind: CiliumNetworkPolicy
metadata:
  name: allow-egress-to-kube-apiserver
spec:
  endpointSelector: {}  # all pods in namespace
  egress:
    - toEntities:
        - kube-apiserver
      toPorts:
        - ports:
            - port: "6443"   # direct node-IP path
              protocol: TCP
            - port: "443"    # ClusterIP path (pre-DNAT)
              protocol: TCP
```

Don't use `toCIDR: 0.0.0.0/0`, Cilium will match it but you've now opened
internet egress to every pod, which defeats the whole point of having a policy.

## Lessons

1. **CNI policy evaluation happens at packet egress, before kube-proxy DNAT.**
 The destination address Cilium evaluates is the one your application
 *typed*, not the one your packet *eventually arrives at*. This is true for
 Calico and Weave too, it's not Cilium-specific.

2. **ClusterIP is part of the policy surface.** Every Service has a ClusterIP
 that pods will hit. If you're writing egress policies and only allowing the
 "real" port, you're going to block half your traffic.

3. **`cilium policy trace` is your friend.** Running it from inside the pod
 that's failing tells you exactly which rule didn't match and why. Reach for
 it earlier than you think.

4. **One outage was annoying. Three was diagnostic.** The first time i
 "fixed" it, i'd just patched a different policy that hadn't been hit yet.
 Document failed hypotheses, they save the next person from re-doing them.
