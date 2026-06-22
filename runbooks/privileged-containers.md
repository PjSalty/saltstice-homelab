# Privileged Container Documentation

## Overview

Every container running with elevated privileges in the cluster, each with its justification.

## Current Privileged Containers

### 1. Image Cleanup CronJob

**File**: `kubernetes/apps/automation/cleanup/image-cleanup-cronjob.yaml`

**Namespace**: `kube-system`

**Schedule**: Daily at 3:00 AM

**Privileges Required**:

| Privilege | Value | Reason |
|-----------|-------|--------|
| `privileged` | `true` | Access to containerd socket and runtime |
| `hostPID` | `true` | View all processes for cleanup decisions |
| `hostPath: /var/lib` | Mounted | Access containerd image storage |
| `hostPath: /var/log` | Mounted | Clean old pod logs |
| `hostPath: /run` | Mounted | Access containerd socket |

**Justification**:

This CronJob prevents disk exhaustion by automatically cleaning:

1. Stopped/exited containers
2. Unused container images (`crictl rmi --prune`)
3. Old pod log files (> 7 days)

The cleanup requires direct access to:

- containerd socket (`/run/k3s/containerd/containerd.sock`)
- RKE2 crictl binary (`/var/lib/rancher/rke2/bin/crictl`)
- Host filesystem for log rotation

**Risk Mitigation**:

- Runs in `kube-system` namespace (restricted access)
- Uses minimal Alpine image
- Read-mostly operations (only deletes unused resources)
- Resource limits enforced (200m CPU, 128Mi memory)
- Job runs on schedule, not continuously
- `ttlSecondsAfterFinished: 86400` cleans up completed jobs

**Alternative Considered**:

Using a non-privileged sidecar or DaemonSet was considered but rejected because:

- crictl requires access to containerd socket (privileged)
- Node-level cleanup cannot be done from unprivileged containers
- Kubernetes garbage collection doesn't handle all cleanup scenarios

## Review Process

When adding new privileged containers:

1. **Document justification** in this file
2. **Minimize privileges** - only request what's needed
3. **Apply resource limits** - prevent resource exhaustion
4. **Restrict namespace** - use `kube-system` when possible
5. **Security review** - consult `security-reviewer` agent

## Audit Command

Find all privileged containers in the cluster:

```bash
# Find privileged: true
kubectl get pods -A -o json | jq -r '
  .items[] |
  select(.spec.containers[].securityContext.privileged == true) |
  "\(.metadata.namespace)/\(.metadata.name)"
'

# Find hostPID: true
kubectl get pods -A -o json | jq -r '
  .items[] |
  select(.spec.hostPID == true) |
  "\(.metadata.namespace)/\(.metadata.name)"
'

# Find hostNetwork: true
kubectl get pods -A -o json | jq -r '
  .items[] |
  select(.spec.hostNetwork == true) |
  "\(.metadata.namespace)/\(.metadata.name)"
'

# Find hostPath mounts
kubectl get pods -A -o json | jq -r '
  .items[] |
  select(.spec.volumes[]?.hostPath != null) |
  "\(.metadata.namespace)/\(.metadata.name): \(.spec.volumes[] | select(.hostPath != null) | .hostPath.path)"
'
```

## Compliance

Per homelab security standards:

> **SEC-002 Privileged Containers**: Running containers with privileged: true without justification
>
> - **Why Bad**: Container escape risk, host access
> - **Instead**: Use specific capabilities, securityContext restrictions

All privileged containers in this homelab have documented justifications above.

## Related Files

| File | Purpose |
|------|---------|
| `kubernetes/apps/automation/cleanup/image-cleanup-cronjob.yaml` | Image cleanup job |
| [runbooks/SSH-access.md](ssh-access.md) | SSH access procedures |
| [troubleshooting/pod-issues.md](../troubleshooting/pod-issues.md) | Pod troubleshooting |
