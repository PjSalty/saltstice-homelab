# Pod Issues Troubleshooting Guide

## Overview

Common pod failures: CrashLoopBackOff, ImagePullBackOff, Pending, and OOMKilled.

## Quick Reference

| Status | Meaning | First Check |
|--------|---------|-------------|
| `Pending` | Pod not scheduled | `kubectl describe pod` - check Events |
| `ContainerCreating` | Setting up container | Volume mounts, secrets, init containers |
| `ImagePullBackOff` | Can't pull image | Image name, registry access, tags |
| `CrashLoopBackOff` | Container keeps crashing | `kubectl logs` - check app errors |
| `OOMKilled` | Out of memory | Increase memory limits |
| `Error` | Container exited with error | `kubectl logs` - check app errors |
| `Evicted` | Node resource pressure | Check node resources |

## CrashLoopBackOff

### What It Means

Container starts, crashes, Kubernetes restarts it, it crashes again. After repeated failures, Kubernetes backs off (waits longer between restarts).

### Diagnosis

```bash
# Check pod status
kubectl get pod <pod-name> -n <namespace>

# Check events
kubectl describe pod <pod-name> -n <namespace>

# Check current logs
kubectl logs <pod-name> -n <namespace>

# Check previous container logs (after crash)
kubectl logs <pod-name> -n <namespace> --previous

# For multi-container pods
kubectl logs <pod-name> -n <namespace> -c <container-name>
```

### Common Causes & Fixes

**Application error**:

```bash
# Check logs for stack traces, errors
kubectl logs <pod-name> -n <namespace> --previous

# Fix: Debug application code, check configuration
```

**Missing configuration**:

```bash
# Check if ConfigMap/Secret exists
kubectl get configmap -n <namespace>
kubectl get secret -n <namespace>

# Check if env vars are set correctly
kubectl describe pod <pod-name> -n <namespace> | grep -A 20 Environment
```

**Database connection failing**:

```bash
# Check if database service exists
kubectl get svc -n <namespace>

# Check if database pod is running
kubectl get pods -n <namespace> -l app=postgres

# Test connectivity from debug pod
kubectl run -it --rm debug --image=alpine -- nc -zv <db-service> 5432
```

**Readiness/Liveness probe failing**:

```bash
# Check probe configuration
kubectl get pod <pod-name> -n <namespace> -o yaml | grep -A 10 livenessProbe

# Check if probe endpoint works
kubectl exec -it <pod-name> -n <namespace> -- curl localhost:8080/health
```

## ImagePullBackOff

### What It Means

Kubernetes cannot pull the container image from the registry.

### Diagnosis

```bash
# Check events for specific error
kubectl describe pod <pod-name> -n <namespace> | grep -A 5 Events

# Common error messages:
# - "unauthorized" - authentication issue
# - "not found" - image doesn't exist
# - "manifest unknown" - tag doesn't exist
```

### Common Causes & Fixes

**Wrong image name/tag**:

```bash
# Check image specification
kubectl get pod <pod-name> -n <namespace> -o yaml | grep image:

# Verify image exists in registry
docker pull <image>:<tag>
# or
curl -s https://harbor.example.com/v2/<repo>/tags/list
```

**Registry authentication**:

```bash
# Check if imagePullSecret is configured
kubectl get pod <pod-name> -n <namespace> -o yaml | grep imagePullSecrets -A 5

# Check if secret exists
kubectl get secret -n <namespace> | grep regcred

# Create/update registry secret
kubectl create secret docker-registry regcred \
  --docker-server=harbor.example.com \
  --docker-username=<user> \
  --docker-password=<pass> \
  -n <namespace>
```

**Harbor/registry unreachable**:

```bash
# Check if Harbor is running
curl -s https://harbor.example.com/api/v2.0/health

# Check network connectivity from node
ssh k8s-worker-1 "curl -s https://harbor.example.com"
```

**Using :latest tag**:

```bash
# :latest can cause caching issues
# Fix: Use specific version tags (e.g., :v1.2.3)

# Force re-pull
kubectl delete pod <pod-name> -n <namespace>
```

## Pending Pods

### What It Means

Pod is waiting to be scheduled to a node.

### Diagnosis

```bash
# Check why pod is pending
kubectl describe pod <pod-name> -n <namespace> | grep -A 10 Events

# Check node capacity
kubectl describe nodes | grep -A 10 "Allocated resources"

# Check node taints
kubectl describe nodes | grep Taints
```

### Common Causes & Fixes

**Insufficient resources**:

```bash
# Check resource requests
kubectl get pod <pod-name> -n <namespace> -o yaml | grep -A 5 resources

# Check available resources on nodes
kubectl top nodes

# Fix: Reduce resource requests or add node capacity
```

**Node selector/affinity not matching**:

```bash
# Check node selector
kubectl get pod <pod-name> -n <namespace> -o yaml | grep -A 3 nodeSelector

# Check node labels
kubectl get nodes --show-labels

# Fix: Update node selector or add labels to nodes
```

**PVC not bound**:

```bash
# Check PVC status
kubectl get pvc -n <namespace>

# If pending, check PV availability
kubectl get pv

# Check storage class
kubectl get storageclass
```

**Taints preventing scheduling**:

```bash
# Check node taints
kubectl describe node <node> | grep Taints

# Check if pod has tolerations
kubectl get pod <pod-name> -n <namespace> -o yaml | grep -A 5 tolerations

# Remove taint (if appropriate)
kubectl taint nodes <node> <taint-key>-
```

## OOMKilled

### What It Means

Container exceeded its memory limit and was killed by the kernel.

### Diagnosis

```bash
# Check termination reason
kubectl describe pod <pod-name> -n <namespace> | grep -A 5 "Last State"

# Check memory limits
kubectl get pod <pod-name> -n <namespace> -o yaml | grep -A 10 resources

# Check actual memory usage (if pod is running)
kubectl top pod <pod-name> -n <namespace>
```

### Fixes

**Increase memory limit**:

```yaml
# Update deployment/pod spec
resources:
  limits:
    memory: "1Gi"  # Increase this
  requests:
    memory: "512Mi"
```

**Fix memory leak**:

- Profile application memory usage
- Check for memory leaks in code
- Review garbage collection settings

**Optimize application**:

- Reduce in-memory caching
- Use streaming instead of loading full datasets
- Configure JVM heap size (for Java apps)

## ContainerCreating Stuck

### What It Means

Pod is stuck setting up - usually volume or network issue.

### Diagnosis

```bash
# Check events
kubectl describe pod <pod-name> -n <namespace> | grep -A 20 Events

# Look for:
# - "MountVolume.SetUp failed"
# - "network not ready"
# - "secret not found"
```

### Common Causes & Fixes

**Volume mount issues**:

```bash
# Check PVC
kubectl get pvc -n <namespace>

# Check if NFS/iSCSI is accessible
showmount -e truenas.example.com

# Restart CSI driver
kubectl rollout restart deployment/democratic-csi-controller -n democratic-csi
```

**Secret not found**:

```bash
# Check if secret exists
kubectl get secret <secret-name> -n <namespace>

# If SOPS-encrypted, check Flux decryption
flux get kustomizations | grep secrets
```

**Init container failing**:

```bash
# Check init container logs
kubectl logs <pod-name> -n <namespace> -c <init-container-name>
```

## Evicted Pods

### What It Means

Node was under resource pressure and evicted pods.

### Diagnosis

```bash
# Check node conditions
kubectl describe node <node> | grep -A 10 Conditions

# Look for:
# - MemoryPressure
# - DiskPressure
# - PIDPressure
```

### Fixes

```bash
# Clean up disk space on node
ssh <node> "crictl rmi --prune"
ssh <node> "journalctl --vacuum-time=3d"

# Find evicted pods
kubectl get pods -A | grep Evicted

# Clean up evicted pods
kubectl delete pods -A --field-selector=status.phase==Failed
```

## General Troubleshooting Commands

```bash
# Get all pods not running
kubectl get pods -A | grep -v Running | grep -v Completed

# Watch pod status
kubectl get pods -n <namespace> -w

# Get pod events sorted by time
kubectl get events -n <namespace> --sort-by='.lastTimestamp'

# Exec into running container
kubectl exec -it <pod-name> -n <namespace> -- /bin/sh

# Port forward to debug
kubectl port-forward <pod-name> -n <namespace> 8080:8080
```

## Related Files

| File | Purpose |
|------|---------|
| [runbooks/node-failure.md](../runbooks/node-failure.md) | Node-level issues |
| [runbooks/storage-failure.md](../runbooks/storage-failure.md) | Storage/volume issues |
| [troubleshooting/Flux-issues.md](flux-issues.md) | Deployment issues |
