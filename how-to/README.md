# How-to guides

Step-by-step setup for the patterns this homelab uses. Each guide is
generic enough to follow against any cluster, your domain, your
ASN, your CIDRs, your decisions.

| Guide | What you end up with |
|---|---|
| [bootstrap-Flux-with-SOPS-Age](bootstrap-flux-with-sops-age.md) | Flux v2 reconciling SOPS-encrypted manifests, with ESO propagating to namespaces |
| [Cilium-BGP-with-MikroTik](cilium-bgp-with-mikrotik.md) | LoadBalancer IPs and pod CIDRs routed natively via BGP, no L2 ARP |
| [Velero-with-SeaweedFS-s3](velero-with-seaweedfs-s3.md) | In-cluster Kubernetes backup, no cloud spend |
