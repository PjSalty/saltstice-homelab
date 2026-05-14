# Cilium

Cilium 1.x bundled with RKE2 v1.x, configured via
`HelmChartConfig` (RKE2's mechanism for overriding bundled chart
values). Kube-proxy replacement on, native routing, eBPF masquerade,
DSR LoadBalancer with maglev, host firewall, Hubble metrics.

## Layout

```
infrastructure/cilium/
├── helmchartconfig.yaml      , RKE2-style override for bundled Cilium chart
└── kustomization.yaml
```

## Configuration that matters

```yaml
kubeProxyReplacement: true
k8sServiceHost: <api-vip>      # haproxy/keepalived VIP for kube-apiserver
k8sServicePort: 6443
routingMode: native            # no overlay, BGP-driven pod routing
autoDirectNodeRoutes: true
ipv4NativeRoutingCIDR: <pod-cidr>
loadBalancer:
  mode: dsr                    # direct server return, lower latency
  algorithm: maglev            # consistent hashing for connection stickiness
bpf:
  masquerade: true             # eBPF replaces iptables masquerade
externalIPs: { enabled: true }
hostFirewall: { enabled: true }
hubble:
  enabled: true
  relay: { enabled: true }
  metrics:
    enabled: [dns, drop, tcp, flow, icmp, http]
```

## kube-proxy replacement

Cilium fully owns Service routing. RKE2's bundled kube-proxy DaemonSet
should NOT exist. Sanity check on every cluster upgrade:

```bash
kubectl get ds -n kube-system kube-proxy   # expected: NotFound
```

If anything reinstalls kube-proxy (a bootstrap script that doesn't know
about the override, a Helm upgrade that ignores `kubeProxyReplacement`),
it'll fight Cilium for ownership of Service VIPs and the result is
racy.

## Per-app NetworkPolicy library

CiliumNetworkPolicies live next to each app (`apps/<app>/networkpolicy/`)
and follow a default-deny + explicit-allow pattern. Common shapes:

- DNS egress allow to `kube-system / k8s-app=kube-dns` only (toCIDR
 doesn't match in-cluster Service VIPs, need `toEndpoints`).
- Ingress from `traefik` and `traefik-dmz` namespaces only on the
 app's port.
- Ingress from `monitoring` namespace for Prometheus scraping.
- Egress to upstream APIs by FQDN where possible, CIDR otherwise.

Examples in this repo: `apps/jellyfin/networkpolicy/`,
`apps/authentik/networkpolicy/`, `apps/docmost/networkpolicy/`.

## Pre-DNAT policy ordering, the gotcha

Cilium evaluates egress policy at packet egress, **before** kube-proxy
DNAT. So a pod connecting to `kubernetes.default.svc:443` is checked
as `:443` (the ClusterIP), not `:6443` (the node-IP behind the DNAT).
Egress rules to `kube-apiserver` must allow **both** ports.

See [`incidents/2026-04-09-cilium-pre-dnat-policy.md`](../../incidents/2026-04-09-cilium-pre-dnat-policy.md)
for the three-outage debugging story.

## Silent-degradation alerting

Cilium 1.x's liveness probe is hardcoded with `brief=true` /
`require-k8s-connectivity=false`. Probe stays green when the BPF
datapath fails. Need outcome-based alerts to catch this; six rules in
`monitoring/prometheus/base/rules/cilium-alerts.yaml` cover the
modes.

See [`incidents/2026-04-27-cilium-silent-degradation.md`](../../incidents/2026-04-27-cilium-silent-degradation.md)
for why these specifically.

## ADR

[`docs/adrs/0003-cilium-over-calico.md`](../../docs/adrs/0003-cilium-over-calico.md)
