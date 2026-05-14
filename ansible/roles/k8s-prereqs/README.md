# K8s-prereqs

Prepares Debian VMs for RKE2 Kubernetes cluster membership. Installs required packages, loads kernel modules, applies sysctl settings, disables swap, enables iSCSI, and deploys RKE2 HelmChartConfig overrides for Cilium and CoreDNS.

## Tasks (tasks/main.yml)

1. Install prerequisite packages (Linux-headers, open-iSCSI, NFS-common, ipvsadm, jq, curl)
2. Load required kernel modules (overlay, br_netfilter, ip_tables, ip_vs variants, nf_conntrack, xt_mark)
3. Persist kernel modules via `/etc/modules-load.d/k8s.conf`
4. Apply Kubernetes sysctl settings (bridge-nf-call, ip_forward, inotify, memory tuning)
5. Set transparent hugepages to `madvise` (runtime + persist via tmpfiles.d)
6. Disable swap and remove from fstab
7. Enable the iscsid service (for iSCSI PVs via democratic-CSI)
8. Create RKE2 server manifests directory (masters only)
9. Deploy RKE2 Cilium HelmChartConfig (masters only)
10. Deploy RKE2 CoreDNS HelmChartConfig (masters only)

## Variables (defaults/main.yml)

| Variable | Default | Description |
|----------|---------|-------------|
| `k8s_kernel_modules` | (list of 9 modules) | Kernel modules for K8s/Cilium networking |
| `k8s_sysctl` | (dict) | Sysctl parameters for Kubernetes |

### Kernel Modules

`overlay`, `br_netfilter`, `ip_tables`, `ip_vs`, `ip_vs_rr`, `ip_vs_wrr`, `ip_vs_sh`, `nf_conntrack`, `xt_mark`

### Sysctl Highlights

- `net.bridge.bridge-nf-call-iptables: 1` -- Required for kube-proxy
- `net.ipv4.ip_forward: 1` -- Required for pod networking
- `vm.swappiness: 1` -- Minimal swap on K8s nodes
- `vm.max_map_count: 524288` -- Required by Elasticsearch-type workloads

## Templates

| File | Destination | Description |
|------|-------------|-------------|
| `k8s-modules.conf.j2` | `/etc/modules-load.d/k8s.conf` | Persisted kernel modules list |
| `rke2-cilium-config.yaml.j2` | `/var/lib/rancher/rke2/server/manifests/rke2-cilium-config.yaml` | Cilium HelmChartConfig: kube-proxy replacement, native routing, DSR, Hubble |
| `rke2-coredns-config.yaml.j2` | `/var/lib/rancher/rke2/server/manifests/rke2-coredns-config.yaml` | CoreDNS HelmChartConfig: pin to control-plane nodes for stability |

### Cilium Configuration

- `kubeProxyReplacement: true` -- Full kube-proxy replacement
- `routingMode: native` with `autoDirectNodeRoutes`
- `loadBalancer.mode: dsr` with Maglev algorithm
- Hubble enabled with relay and UI
- BPF masquerade and socket-level LB

### CoreDNS Configuration

Pins CoreDNS pods to control-plane nodes. When CoreDNS runs on workers, VPA/Karpenter pod churn can trigger Cilium eBPF service map staleness causing DNS outages.

## Tags

`k8s-prereqs`, `packages`, `kernel`, `sysctl`, `performance`, `rke2`
