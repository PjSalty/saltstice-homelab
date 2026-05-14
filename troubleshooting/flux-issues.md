# FluxCD Issues Troubleshooting Guide

## Overview

This guide covers FluxCD reconciliation failures, HelmRelease issues, and GitOps problems in the Salty Homelab.

## Quick Reference

| Status | Meaning | First Check |
|--------|---------|-------------|
| `False` (Ready) | Reconciliation failed | `flux get all -A` |
| `Suspended` | Reconciliation paused | Check if intentional |
| `Stalled` | No progress being made | Check source availability |
| `Helm upgrade failed` | Helm release error | `flux logs --kind=HelmRelease` |

## Checking Flux Status

```bash
# Overall status
flux check

# All resources
flux get all -A

# Specific types
flux get kustomizations -A
flux get helmreleases -A
flux get sources git -A
flux get sources helm -A

# Watch for changes
flux get kustomizations -A -w
```

## Kustomization Failures

### Diagnosis

```bash
# Check kustomization status
flux get kustomization <name> -n flux-system

# Get detailed error
kubectl describe kustomization <name> -n flux-system

# Check events
kubectl get events -n flux-system --field-selector involvedObject.name=<name>
```

### Common Causes & Fixes

**Source not ready**:

```bash
# Check GitRepository
flux get sources git -A

# Force reconcile source
flux reconcile source git flux-system

# Check source details
kubectl describe gitrepository flux-system -n flux-system
```

**YAML syntax error**:

```bash
# Check Flux logs
flux logs --kind=Kustomization --name=<name>

# The error will show file and line number
# Fix: Correct YAML syntax in the specified file
```

**Missing dependency**:

```bash
# Check dependsOn in kustomization
kubectl get kustomization <name> -n flux-system -o yaml | grep -A 5 dependsOn

# Make sure dependency is ready
flux get kustomization <dependency-name>
```

**SOPS decryption failure**:

```bash
# Check if sops-age secret exists
kubectl get secret sops-age -n flux-system

# Check decryption provider config
kubectl get kustomization <name> -n flux-system -o yaml | grep -A 5 decryption

# Verify SOPS file format
sops -d <file.yaml>
```

### Force Reconciliation

```bash
# Reconcile with source refresh
flux reconcile kustomization <name> --with-source

# Suspend and resume to reset
flux suspend kustomization <name>
flux resume kustomization <name>
```

## HelmRelease Failures

### Diagnosis

```bash
# Check HelmRelease status
flux get helmrelease <name> -n <namespace>

# Get detailed status
kubectl describe helmrelease <name> -n <namespace>

# Check Helm history
helm history <name> -n <namespace>

# Check Flux Helm controller logs
flux logs --kind=HelmRelease --name=<name> -n <namespace>
```

### Common Causes & Fixes

**Chart not found**:

```bash
# Check HelmRepository
flux get sources helm -A

# Verify chart exists in repository
helm search repo <chart-name>

# Reconcile HelmRepository
flux reconcile source helm <repo-name>
```

**Values validation failed**:

```bash
# Check values in HelmRelease
kubectl get helmrelease <name> -n <namespace> -o yaml

# Try helm template locally
helm template <name> <chart> --values values.yaml

# Fix: Correct values according to chart schema
```

**Timeout during upgrade**:

```bash
# Check if pods are stuck
kubectl get pods -n <namespace>

# Increase timeout in HelmRelease
spec:
  timeout: 15m  # Increase from default 5m

# Or fix underlying pod issue (see pod-issues.md)
```

**Pending upgrade**:

```bash
# Check Helm release state
helm status <name> -n <namespace>

# If stuck in pending-upgrade:
helm rollback <name> -n <namespace>

# Force reconcile
flux reconcile helmrelease <name> -n <namespace>
```

**Failed hooks**:

```bash
# Check hook jobs
kubectl get jobs -n <namespace>

# Check hook pod logs
kubectl logs -n <namespace> job/<hook-job-name>

# Delete failed hook jobs and retry
kubectl delete job <hook-job-name> -n <namespace>
flux reconcile helmrelease <name> -n <namespace>
```

### Rollback HelmRelease

```bash
# Check release history
helm history <name> -n <namespace>

# Rollback to previous version
helm rollback <name> <revision> -n <namespace>

# Update HelmRelease in Git to match
# (Or Flux will try to upgrade again)
```

## Source Failures

### GitRepository Issues

```bash
# Check GitRepository status
flux get sources git -A
kubectl describe gitrepository flux-system -n flux-system

# Common errors:
# - "authentication required" - Deploy key issue
# - "couldn't find remote ref" - Branch doesn't exist
# - "repository not found" - Wrong URL
```

**Deploy key authentication**:

```bash
# Check if deploy key secret exists
kubectl get secret flux-system -n flux-system

# Verify key is added to GitLab
# GitLab  Project  Settings  Repository  Deploy Keys

# Regenerate if needed
flux create secret git flux-system \
  --url=ssh://git@gitlab.example.com/infrastructure/homelab-complete.git \
  --private-key-file=<path-to-key>
```

### HelmRepository Issues

```bash
# Check HelmRepository status
flux get sources helm -A
kubectl describe helmrepository <name> -n flux-system

# Common errors:
# - "401 Unauthorized" - Need credentials
# - "connection refused" - Registry unreachable
```

**Authentication**:

```bash
# Create secret for authenticated Helm repo
kubectl create secret generic helm-repo-creds \
  --from-literal=username=<user> \
  --from-literal=password=<pass> \
  -n flux-system

# Reference in HelmRepository
spec:
  secretRef:
    name: helm-repo-creds
```

## Image Automation Issues

### ImageRepository Failures

```bash
# Check ImageRepository
flux get images repository -A

# Check for errors
kubectl describe imagerepository <name> -n flux-system
```

### ImagePolicy Not Selecting

```bash
# Check ImagePolicy
flux get images policy -A

# Verify policy is selecting correct tags
kubectl describe imagepolicy <name> -n flux-system

# Test policy locally
flux get images policy <name> -n flux-system -o yaml
```

## Notification Issues

### Alerts Not Firing

```bash
# Check Alert configuration
kubectl get alert -A
kubectl describe alert <name> -n flux-system

# Check Provider
kubectl get provider -A
kubectl describe provider <name> -n flux-system

# Verify webhook URL is accessible
```

## Suspension and Recovery

### Intentionally Suspend Flux

```bash
# Suspend a kustomization (stops reconciliation)
flux suspend kustomization <name>

# Suspend a HelmRelease
flux suspend helmrelease <name> -n <namespace>

# Resume when ready
flux resume kustomization <name>
flux resume helmrelease <name> -n <namespace>
```

### Emergency: Suspend All

```bash
# Suspend all kustomizations
flux suspend kustomization --all

# Resume all
flux resume kustomization --all
```

## Debugging Commands

```bash
# Get all Flux events
kubectl get events -n flux-system --sort-by='.lastTimestamp'

# Flux controller logs
kubectl logs -n flux-system deployment/source-controller
kubectl logs -n flux-system deployment/kustomize-controller
kubectl logs -n flux-system deployment/helm-controller

# Trace reconciliation
flux trace kustomization <name>

# Export current state
flux export kustomization <name> > kustomization.yaml
```

## Common Patterns

### Dependency Chain

```yaml
# Make sure resources deploy in order
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: my-app
spec:
  dependsOn:
    - name: secrets      # Deploy secrets first
    - name: database     # Then database
  # ...
```

### Health Checks

```yaml
# Wait for resources to be healthy
spec:
  healthChecks:
    - apiVersion: apps/v1
      kind: Deployment
      name: my-app
      namespace: my-namespace
```

### Retry Strategy

```yaml
# Configure retry behavior
spec:
  retryInterval: 5m
  timeout: 10m
```

## Related Files

| File | Purpose |
|------|---------|
| `kubernetes/flux-system/` | Flux bootstrap |
| `kubernetes/infrastructure/` | Infrastructure Kustomizations |
| `kubernetes/apps/` | Application HelmReleases |
| [architecture/polyrepo-design.md](../architecture/polyrepo-design.md) | GitOps procedures |
