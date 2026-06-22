# New Service Deployment Checklist

Everything needed to deploy a new Kubernetes app, in order. Skip a step and you get an incomplete deployment that needs cleanup.

## Pre-Deployment Checklist

### 1. NetBox Registration (Required First)

All infrastructure resources must exist in NetBox before provisioning.

- [ ] Create IP allocation in NetBox for any new VMs/services
- [ ] Add service to the appropriate namespace record
- [ ] Verify DNS entry exists or will be created by the deployment

### 2. Repository Structure

Create the manifest structure in `homelab-kubernetes/`:

```
apps/
  <namespace>/
    <app-name>/
      kustomization.yaml     # Lists all resource files
      helmrelease.yaml       # HelmRelease (if using Helm)
      configmap.yaml         # App configuration (if needed)
      namespace.yaml         # Namespace definition (if new)
      networkpolicy.yaml     # Network isolation rules
      autoscaling/
        kustomization.yaml
        vpa.yaml             # VerticalPodAutoscaler (REQUIRED)
        hpa.yaml             # HorizontalPodAutoscaler (if stateless)
```

### 3. Helm Chart Research

Before writing the HelmRelease:

- [ ] Find the official Helm chart and repository
- [ ] Pin to a specific chart version (no `*` or `latest`)
- [ ] Review chart values for security-relevant options
- [ ] Check if chart supports `securityContext` settings

```yaml
# Always pin chart version
spec:
  chart:
    spec:
      chart: my-app
      version: "1.2.3"   # Pinned, never use version ranges
```

### 4. Secrets Setup

- [ ] Add credentials to `secrets/credential-registry.yaml`
- [ ] Generate initial credentials via rotation playbook:

```bash
cd homelab-ansible
ansible-playbook playbooks/99-rotate-credentials.yml -e mode=generate
```

- [ ] Create encrypted secret in `infrastructure/secrets` repo under
 `kubernetes/<namespace>/`
- [ ] Verify SOPS annotation on secret file

### 5. Ingress Configuration

If the service needs external access:

- [ ] Create IngressRoute in `apps/<namespace>/<app>/ingressroute.yaml`
- [ ] Use correct Traefik entrypoint (`websecure` for HTTPS)
- [ ] Reference the wildcard TLS secret `wildcard-tls` in `cert-manager`
- [ ] Add middleware for auth (Authentik forward-auth) if needed

```yaml
apiVersion: traefik.io/v1alpha1
kind: IngressRoute
metadata:
  name: my-app
  namespace: my-namespace
spec:
  entryPoints:
    - websecure
  routes:
    - match: Host(`my-app.example.com`)
      kind: Rule
      services:
        - name: my-app
          port: 80
  tls:
    secretName: wildcard-tls
```

### 6. Security Requirements (All Required)

Every deployment MUST have:

- [ ] `securityContext.runAsNonRoot: true`
- [ ] `securityContext.runAsUser: <non-zero UID>`
- [ ] `securityContext.readOnlyRootFilesystem: true` (or justified exception)
- [ ] `securityContext.allowPrivilegeEscalation: false`
- [ ] `securityContext.capabilities.drop: ["ALL"]`
- [ ] Resource requests AND limits defined
- [ ] Liveness and readiness probes

```yaml
containers:
  - name: my-app
    securityContext:
      runAsNonRoot: true
      runAsUser: 1000
      readOnlyRootFilesystem: true
      allowPrivilegeEscalation: false
      capabilities:
        drop: ["ALL"]
    resources:
      requests:
        cpu: 100m
        memory: 128Mi
      limits:
        cpu: 500m
        memory: 512Mi
    livenessProbe:
      httpGet:
        path: /health
        port: 8080
      initialDelaySeconds: 30
    readinessProbe:
      httpGet:
        path: /ready
        port: 8080
```

### 7. Autoscaling (Required for All Deployments)

Every Deployment and StatefulSet MUST have a VPA:

- [ ] Create `autoscaling/vpa.yaml` with `updateMode: Auto`
- [ ] Set appropriate `minAllowed` and `maxAllowed` per container
- [ ] Add `autoscaling` to parent `kustomization.yaml`
- [ ] If stateless + variable traffic: add HPA and use memory-only VPA

```yaml
# autoscaling/vpa.yaml
apiVersion: autoscaling.k8s.io/v1
kind: VerticalPodAutoscaler
metadata:
  name: my-app
  namespace: my-namespace
spec:
  targetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: my-app
  updatePolicy:
    updateMode: "Auto"
  resourcePolicy:
    containerPolicies:
      - containerName: my-app
        minAllowed:
          cpu: 50m
          memory: 64Mi
        maxAllowed:
          cpu: 1000m
          memory: 1Gi
```

### 8. Network Policy

Every namespace needs a NetworkPolicy:

- [ ] Default deny all ingress and egress
- [ ] Explicit allow rules for required communication
- [ ] Allow ingress from Traefik namespace
- [ ] Allow egress to required services (DNS, database, external APIs)

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: my-app
  namespace: my-namespace
spec:
  podSelector: {}
  policyTypes:
    - Ingress
    - Egress
  ingress:
    - from:
        - namespaceSelector:
            matchLabels:
              kubernetes.io/metadata.name: traefik
  egress:
    - to:
        - namespaceSelector:
            matchLabels:
              kubernetes.io/metadata.name: kube-system
      ports:
        - port: 53
          protocol: UDP
```

### 9. Flux Kustomization

Add the app to Flux in `homelab-kubernetes/apps/<namespace>/kustomization.yaml`:

```yaml
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: my-app
  namespace: flux-system
spec:
  interval: 30m
  path: ./apps/my-namespace/my-app
  prune: true
  sourceRef:
    kind: GitRepository
    name: flux-system
  dependsOn:
    - name: secrets        # Always depend on secrets
    - name: infrastructure # Depend on infrastructure if using storage
```

### 10. Storage (If Stateful)

For stateful applications:

- [ ] Use iSCSI for databases (PostgreSQL, MySQL), never NFS for databases
- [ ] Use NFS for file storage (media, documents)
- [ ] Define PVC with appropriate StorageClass
- [ ] Add Velero backup annotation if data is important

```yaml
# iSCSI StorageClass for databases
storageClassName: truenas-iscsi

# NFS StorageClass for file storage
storageClassName: truenas-nfs

# Velero backup annotation
metadata:
  annotations:
    backup.velero.io/backup-volumes: data
```

## Deployment Steps

### Step 1: Commit and Push

```bash
cd homelab-kubernetes
git checkout -b feat/add-my-app
git add apps/my-namespace/my-app/
git commit -m "feat(my-namespace): add my-app deployment"
git push -u origin feat/add-my-app
```

### Step 2: Create MR in GitLab

```bash
glab mr create \
  --title "feat(my-namespace): add my-app" \
  --target-branch main \
  --remove-source-branch
```

### Step 3: CI Validation

Wait for CI pipeline to pass:

- YAML linting
- Kyverno policy validation (if enabled in CI)
- Secret encryption check (no plaintext secrets)

### Step 4: Merge and Watch Flux

```bash
# After merge, watch Flux reconcile
flux get kustomizations -A -w

# Watch specific kustomization
flux get kustomization my-app -n flux-system -w

# Watch pods start
kubectl get pods -n my-namespace -w
```

### Step 5: Verify Deployment

```bash
# Check pods are running
kubectl get pods -n my-namespace

# Check ingress route is registered
kubectl get ingressroute -n my-namespace

# Test the service endpoint
curl -I https://my-app.example.com

# Check certificate is valid
echo | openssl s_client -connect my-app.example.com:443 2>/dev/null \
  | openssl x509 -noout -dates
```

## Post-Deployment Verification

- [ ] Service accessible via HTTPS at expected URL
- [ ] TLS certificate is valid (wildcard cert applied)
- [ ] Authentication working (if Authentik forward-auth applied)
- [ ] Metrics appearing in Grafana (if ServiceMonitor added)
- [ ] Logs visible in Loki/Grafana
- [ ] VPA has recommendations (check after 24h)
- [ ] Velero backup running (if stateful)
- [ ] Credentials saved in Vaultwarden

## Common Mistakes to Avoid

| Mistake | Consequence | Fix |
|---------|-------------|-----|
| Using `:latest` image tag | Non-reproducible deployments | Always pin to specific version |
| No resource limits | Node OOM kills | Set both requests and limits |
| No readiness probe | Traffic sent to unready pods | Add readiness probe |
| Missing NetworkPolicy | Unrestricted lateral movement | Add default-deny policy |
| NFS for PostgreSQL | Data corruption | Use iSCSI for databases |
| No VPA | Resource over/under-provisioning | Add VPA in Auto mode |
| Plaintext secret in Git | Security breach | Use SOPS encryption |

## Related Documentation

| Document | Purpose |
|----------|---------|
| [runbooks/credential-rotation.md](credential-rotation.md) | Managing app credentials |
| [runbooks/certificate-management.md](certificate-management.md) | TLS certificate setup |
| [troubleshooting/Flux-issues.md](../troubleshooting/flux-issues.md) | Flux reconciliation issues |
| [troubleshooting/pod-issues.md](../troubleshooting/pod-issues.md) | Pod startup issues |
