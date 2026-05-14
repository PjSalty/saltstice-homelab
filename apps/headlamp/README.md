# Headlamp

Headlamp is a Kubernetes dashboard that provides a web UI for cluster management and observability. It is protected by Authentik SSO via Traefik forward-auth.

## Architecture

Headlamp runs as a stateless Deployment with an init container that generates a kubeconfig from the ServiceAccount token. The dashboard backend uses this kubeconfig to communicate with the Kubernetes API server.

Authentication is handled by a custom forward-auth middleware that strips the `Authorization` header, ensuring Headlamp's K8s proxy uses the ServiceAccount token (read-only ClusterRole) rather than the Authentik Bearer token.

- **Namespace**: `headlamp`
- **FQDN**: `https://k8s.example.com`
- **Version**: v0.40.0
- **TLS**: Wildcard certificate (`wildcard-tls`)

## Directory Structure

```
headlamp/
  base/
    kustomization.yaml
    namespace.yaml
    autoscaling/
      kustomization.yaml
      hpa.yaml
      vpa.yaml
    deployments/
      deployment.yaml
    ingress/
      ingress.yaml
      middleware.yaml
    pdb/
      pdb.yaml
    rbac/
      rbac.yaml
      serviceaccount.yaml
    services/
      service.yaml
```

## File Descriptions

### `base/kustomization.yaml`

Root Kustomization assembling all resources. Notes that secrets are managed by the infrastructure/secrets repo.

### `base/namespace.yaml`

Creates the `headlamp` namespace with wildcard TLS and Goldilocks labels.

### `base/deployments/deployment.yaml`

Headlamp Deployment:
- Replica count managed by HPA
- **Init container** (`generate-kubeconfig`): Creates a kubeconfig file from the ServiceAccount token in an emptyDir volume. Runs as non-root (UID 100), read-only filesystem.
- **Main container** (`headlamp`):
 - Image: `${IMAGE_HEADLAMP}`
 - Listens on port 4466
 - Uses the generated kubeconfig via `-kubeconfig=/kubeconfig/config`
 - Runs as non-root (UID 100), read-only filesystem
 - Health probes on `/` (port 4466)
 - EmptyDir volumes for `/tmp`, `/home/headlamp/.config`, and `/kubeconfig`

### `base/services/service.yaml`

ClusterIP Service mapping port 80 to container port 4466.

### `base/ingress/ingress.yaml`

Kubernetes Ingress for `k8s.example.com`:
- Traefik `websecure` entrypoint
- Uses the custom `forward-auth-no-bearer` middleware (not the standard forward-auth)
- Wildcard TLS certificate

### `base/ingress/middleware.yaml`

Custom Traefik ForwardAuth Middleware (`forward-auth-no-bearer`):
- Forwards authentication to Authentik's embedded outpost
- Passes all standard Authentik response headers (`X-authentik-*`)
- Critically, does NOT pass the `Authorization` header to the backend
- This prevents Headlamp from using the Authentik Bearer token for K8s API calls, ensuring it falls back to the ServiceAccount token with restricted read-only permissions

### `base/rbac/serviceaccount.yaml`

ServiceAccount `headlamp` and ClusterRoleBinding to the `headlamp-dashboard` ClusterRole (read-only, not cluster-admin).

### `base/rbac/rbac.yaml`

ClusterRole `headlamp-dashboard` with comprehensive read-only access:
- Core resources: pods, services, ConfigMaps, secrets, nodes, PVs, PVCs, etc.
- Apps: deployments, StatefulSets, DaemonSets, replicasets
- Batch: jobs, cronjobs
- Networking: ingresses, NetworkPolicies
- Storage: storageclasses, volumeattachments
- RBAC: roles, clusterroles, bindings
- Policy: PDBs
- Custom resources: CRDs
- FluxCD: helmreleases, gitrepositories, kustomizations
- Cilium: NetworkPolicies
- Traefik: ingressroutes, middlewares, serverstransports, TLS options
- cert-manager: certificates, issuers
- Metrics: nodes, pods (metrics.K8s.io)

All verbs are read-only: `get`, `list`, `watch`.

### `base/pdb/pdb.yaml`

PodDisruptionBudget with `minAvailable: 1`.

### `base/autoscaling/hpa.yaml`

HorizontalPodAutoscaler:
- Min 1, max 2 replicas
- Scales on CPU utilization at 70% target
- Scale-down stabilization: 600s, scale-up: 120s

### `base/autoscaling/vpa.yaml`

VPA (Auto mode, memory-only since HPA manages CPU):
- Memory: 64Mi-512Mi

## Secrets

No secrets are defined in this directory. Secrets are managed by the infrastructure/secrets repo.

## Dependencies

- Traefik ingress controller
- Authentik SSO (forward-auth via embedded outpost)
- cert-manager wildcard certificate
- Kubernetes API server
