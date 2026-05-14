# prometheus

Standalone Prometheus server deployment (pre-HelmRelease configuration). This directory contains a complete Prometheus setup with custom scrape configs, RBAC, storage, ingress, alert rules, and ServiceMonitors.

## Overview

The primary Prometheus instance is now deployed via the kube-prometheus-stack HelmRelease in `monitoring-release.yaml`. This directory serves as the custom resource layer: alert rules (`PrometheusRule`) and ServiceMonitors defined here are referenced directly from the root `kustomization.yaml` and consumed by the Helm-managed Prometheus operator.

## Directory Structure

```
prometheus/
  base/
    config/           Prometheus scrape configuration (ConfigMap)
    deployment/       Standalone Prometheus server Deployment
    ingress/          TLS certificate and Ingress for metrics.example.com
    rbac/             ServiceAccount, ClusterRole, ClusterRoleBinding
    rules/            PrometheusRule alert definitions (actively deployed)
    service/          ClusterIP Service on port 9090
    servicemonitors/  Kubernetes API and kubelet ServiceMonitors
    storage/          50Gi NFS PVC for metrics data
    namespace.yaml    Monitoring namespace definition
    kustomization.yaml
```

See `base/README.md` for detailed file descriptions.
