# How-to: Cilium BGP peering with a MikroTik router

For self-hosted clusters where you want LoadBalancer service IPs
(MetalLB-allocated or otherwise) routed natively to nodes via BGP,
without an external L2 ARP setup.

## Prerequisites

- Cilium 1.x+ with BGP control plane enabled in the Helm values:
  ```yaml
  bgpControlPlane:
    enabled: true
  ```
- A MikroTik router running RouterOS 7+ (BGP RFC support).
- Cluster nodes and router on the same L3 segment (same VLAN or
 routable between them).
- An ASN for the cluster and one for the router. Private ASN range
 is `<asn>-65534` for ASN16 or `4200000000-4294967294` for ASN32.

## On the cluster

### Define the BGP peering policy

```yaml
apiVersion: cilium.io/v2alpha1
kind: CiliumBGPPeeringPolicy
metadata:
  name: bgp-policy
spec:
  nodeSelector:
    matchLabels:
      bgp-peer: "true"
  virtualRouters:
    - localASN: <asn>
      exportPodCIDR: true
      neighbors:
        - peerAddress: <host>/32
          peerASN: <asn>
          authSecretRef: cilium-bgp-md5
          eBGPMultihopTTL: 1
          gracefulRestart:
            enabled: true
            restartTimeSeconds: 60
      serviceSelector:
        matchExpressions:
          - { key: somekey, operator: NotIn, values: [neverused] }
```

`exportPodCIDR: true` advertises pod-network routes. `serviceSelector`
catches every Service with `type: LoadBalancer` and advertises a `/32`
for each allocated VIP.

### Label nodes that should peer

```bash
kubectl label node <node> bgp-peer=true
```

Apply selectively if you want only specific nodes to BGP-peer.

### Create the MD5 auth secret

```bash
kubectl create secret generic cilium-bgp-md5 \
  --namespace kube-system \
  --from-literal=password='<shared-secret-here>'
```

Reference it from the peering policy via `authSecretRef`.

## On the MikroTik

```routeros
/routing bgp connection
add as=<asn> \
    name=cluster-master-1 \
    remote.address=<internal-ip> remote.as=<asn> \
    local.address=<internal-ip> \
    input.filter=accept-cluster-routes \
    output.filter=advertise-no-routes \
    multihop=no \
    auth-key=<shared-secret-here>

# repeat for each node that has bgp-peer=true
```

`auth-key` matches the K8s secret. `input.filter` should accept the
pod CIDR and any LB CIDR you've allocated; tighten it to your actual
ranges, not `accept-everything`.

```routeros
/routing filter rule
add chain=accept-cluster-routes rule="if (dst in 10.42.0.0/16) { accept }"
add chain=accept-cluster-routes rule="if (dst in <vlan-cidr>) { accept }"
add chain=accept-cluster-routes rule="reject"
```

Replace `10.42.0.0/16` with your actual pod CIDR and `<vlan-cidr>`
with your LB pool.

## Verify

On the cluster:

```bash
cilium bgp peers
# expected: each peer shows session_state=established
cilium bgp routes advertised
# expected: pod CIDR + one /32 per LoadBalancer service
```

On the router:

```routeros
/routing bgp peer print
# Established
/routing route print where bgp
# pod CIDR + LB /32s
```

## Common failures

**Session not coming up, no auth error**: ASNs or local-address
mismatched. Check both sides.

**Session up but no routes advertised**: `exportPodCIDR` not enabled,
or `serviceSelector` doesn't match anything. `Cilium BGP routes
advertised` will be empty.

**Routes advertised but client can't reach service**: router didn't
install the route into the FIB. Check `/routing route print` filters
and the `accept-cluster-routes` filter chain.

**MD5 mismatch (silent on Cilium side)**: RouterOS will log
"BGP-MD5: failed". Check `/log print where topics~"bgp"`.
The K8s secret contents must match `auth-key` byte for byte; quote
or escape any shell metacharacters when creating the K8s secret.

## What this gives you

LB service IPs become routable directly to the node hosting the
backing pod, no L2 ARP gymnastics. Failover is BGP-fast (≤5s with
graceful restart). Pod-to-pod traffic across the router uses the
same BGP-advertised routes, no overlay, no SNAT.

## Caveats

`eBGPMultihopTTL: 1` because the router and nodes are L2-adjacent in
this setup. Bump TTL if you BGP-peer through other routers.

Cilium BGP is not the same as MetalLB-BGP-mode. With Cilium BGP, you
disable MetalLB-BGP-speaker entirely; Cilium itself does the
advertisement. MetalLB still handles IP allocation from the pool.
you just don't run its speaker DaemonSet.

`gracefulRestart` must be enabled on both sides for failover to be
seamless during Cilium agent restarts. RouterOS supports it natively.
