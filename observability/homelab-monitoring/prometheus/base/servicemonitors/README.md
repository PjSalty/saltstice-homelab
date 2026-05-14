# prometheus/base/servicemonitors

Prometheus Operator ServiceMonitor resources for core Kubernetes component metrics.

## Files

| File | Description |
|------|-------------|
| `kubernetes-servicemonitor.yaml` | Contains three ServiceMonitor definitions for core Kubernetes metrics: `kube-apiserver`, `kubelet`, and `cadvisor`. |

## ServiceMonitors

### kube-apiserver

- **Namespace selector**: `default`
- **Label selector**: `component: apiserver, provider: kubernetes`
- **Endpoint**: `https` port, 30s interval, HTTPS with service account CA and bearer token
- **Purpose**: API server request metrics, latency, error rates

### kubelet

- **Namespace selector**: `kube-system`
- **Label selector**: `app.kubernetes.io/name: kubelet`
- **Endpoint**: `https-metrics` port, 30s interval, HTTPS with `insecureSkipVerify: true`
- **Relabeling**: Extracts `node` label from `__meta_kubernetes_node_name`
- **Purpose**: Kubelet metrics including pod lifecycle, volume operations, runtime stats

### cadvisor

- **Namespace selector**: `kube-system`
- **Label selector**: `app.kubernetes.io/name: kubelet`
- **Endpoint**: `https-metrics` port at path `/metrics/cadvisor`, 30s interval, HTTPS
- **Relabeling**: Extracts `node` label from `__meta_kubernetes_node_name`
- **Purpose**: Container-level CPU, memory, disk, and network usage metrics

## Authentication

All three ServiceMonitors use the mounted service account credentials:
- CA file: `/var/run/secrets/kubernetes.io/serviceaccount/ca.crt`
- Bearer token: `/var/run/secrets/kubernetes.io/serviceaccount/token`

The kubelet and cadvisor endpoints use `insecureSkipVerify: true` because kubelet certificates are typically self-signed.
