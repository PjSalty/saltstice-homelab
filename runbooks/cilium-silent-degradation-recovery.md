# Runbook: Cilium silent-degradation recovery

When a Cilium agent on one node passes its liveness probe but its
datapath has stopped forwarding. Pods on that node start flapping or
fail with "no endpoints available" for in-cluster Services.

**Detection**: usually a Prometheus alert from the
`cilium-degradation` rule pack, `CiliumAgentDatapathErrors`,
`CiliumEndpointRegenerationFailing`, or `CiliumAgentNoEndpoints`.
Without those alerts, the first sign is CI failures or specific apps
on one node going unreachable.

## Recovery (proven)

```bash
# 1. Identify the bad node
NODE=<affected-node>

# 2. Cordon it
kubectl cordon "$NODE"

# 3. Drain it
kubectl drain "$NODE" --ignore-daemonsets --delete-emptydir-data

# 4. Find the Cilium agent pod on that node
POD=$(kubectl get pod -n kube-system -l k8s-app=cilium \
        --field-selector spec.nodeName="$NODE" -o name | head -1)

# 5. Delete it, DaemonSet recreates it
kubectl delete "$POD" -n kube-system

# 6. Wait for the new agent to be Ready
kubectl wait pod -n kube-system -l k8s-app=cilium \
  --field-selector spec.nodeName="$NODE" --for=condition=Ready --timeout=120s

# 7. Uncordon
kubectl uncordon "$NODE"
```

## Why not Flux-managed cutover

Replacing the Cilium HelmRelease via Flux during an active failure
fails: chart fetch needs DNS, DNS needs Cilium, `cleanupOnFail: true`
in the HelmRelease can nuke the partial release and leave the cluster
worse. **Do not attempt the Flux path on the affected cluster.**

If you do need to upgrade Cilium itself, do it from a Semaphore /
Ansible job that runs `helm upgrade` directly against the cluster
with the chart pre-fetched, OR from a separate management cluster.

## Verify recovery

```bash
# Datapath sanity from a pod on the recovered node
kubectl debug node/"$NODE" -it --image=alpine -- sh
# inside: ping a Service VIP, then a pod IP

# Cilium status from the agent
kubectl exec -n kube-system "$POD" -- cilium status
# expected: KubeProxyReplacement: True, all "Healthy"

# Hubble on the node
kubectl exec -n kube-system "$POD" -- hubble status
```

## Why this happens

Cilium 1.x's liveness probe is hardcoded with `brief=true` and
`require-k8s-connectivity=false`. The probe checks "process responds",
not "datapath forwards." If the BPF datapath gets into a degraded
state but the agent's RPC server is alive, the probe stays green and
kubelet never restarts the pod.

Six Prometheus alerts catch the next degradation in ~5 minutes
instead of "unknown days":

- `CiliumAgentDatapathErrors`
- `CiliumEndpointRegenerationFailing`
- `CiliumIdentityCacheStale`
- `CiliumPolicyImportFailures`
- `CiliumAgentNoEndpoints`
- `CiliumBPFMapPressure`

If those aren't shipped, ship them now.

## Related

[Postmortem: Cilium silent degradation 2026-04-27](../incidents/2026-04-27-cilium-silent-degradation.md)
