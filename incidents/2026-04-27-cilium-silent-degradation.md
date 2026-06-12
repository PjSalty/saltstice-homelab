# Cilium silent degradation: when liveness probes lie

**Date:** 2026-04-27
**Impact:** One Cilium agent ran in a half-broken state for an unknown duration.
23 internal jobs stalled, 14 pods flapped, CI returned "no endpoints available."

## Summary

A Cilium agent on one Kubernetes node was silently broken: its liveness probe
kept passing, but its datapath wasn't forwarding traffic. The agent process
existed and responded, so kubelet never restarted it. The first sign that
anything was wrong was CI starting to fail intermittently when jobs landed on
that node.

## Symptoms

- `kubectl get pods -n kube-system | grep cilium` showed all agents `Running 1/1`.
- Liveness probes green for hours.
- 14 pods on the affected node flapped or restarted with no clear cause.
- CI jobs scheduled to that node failed with `no endpoints available for service kyverno-svc`.
- `cilium status` from inside the bad agent showed datapath errors but the
 process kept responding to its probe.

## Root cause

Cilium 1.x's liveness probe is hardcoded with `brief=true` and
`require-k8s-connectivity=false`. It checks "is the agent process responding",
not "is the agent forwarding traffic." If the BPF datapath gets into a
degraded state but the agent's RPC server is still alive, the probe stays
green and kubelet never restarts the pod.

These flags aren't exposed as Helm values, so you can't tune the probe to be
strict.

## Recovery (proven)

```bash
# 1. Cordon the affected node
kubectl cordon <node>

# 2. Drain it
kubectl drain <node> --ignore-daemonsets --delete-emptydir-data

# 3. Delete the bad Cilium agent pod (DaemonSet recreates it)
kubectl delete pod -n kube-system <cilium-pod-on-bad-node>

# 4. Uncordon
kubectl uncordon <node>
```

This works. i tried a Flux-managed cutover (replace the Cilium HelmRelease
with a known-good one) and it failed: the chart fetch needs DNS, DNS needs
Cilium, and `cleanupOnFail: true` nuked the partial release. Lesson:
**don't manage critical infrastructure with the CNI it depends on.** Or at
minimum, use a separate non-Flux path (Semaphore, a script, a runbook) for
recovering the CNI itself.

## Permanent fix: detection alerts

Six Prometheus alerts catch the next degradation in ~5 minutes instead of
"unknown days":

```yaml
groups:
  - name: cilium-degradation
    rules:
      - alert: CiliumAgentDatapathErrors
        expr: rate(cilium_drop_count_total{reason!~"Stale or unroutable IP"}[5m]) > 1
        for: 5m
        annotations:
          summary: "Cilium agent {{ $labels.k8s_app }} on {{ $labels.instance }} is dropping packets"

      - alert: CiliumEndpointRegenerationFailing
        expr: rate(cilium_endpoint_regeneration_total{outcome="fail"}[10m]) > 0
        for: 10m

      - alert: CiliumIdentityCacheStale
        expr: cilium_identity_cache_size == 0 and on(instance) up{job="cilium"} == 1
        for: 5m

      - alert: CiliumPolicyImportFailures
        expr: rate(cilium_policy_import_errors_total[10m]) > 0
        for: 5m

      - alert: CiliumAgentNoEndpoints
        expr: cilium_endpoint_count < 1 and on(instance) up{job="cilium"} == 1
        for: 5m

      - alert: CiliumBPFMapPressure
        expr: cilium_bpf_map_pressure > 0.8
        for: 10m
```

These monitor *outcomes* (drops, regeneration failures, policy import errors)
not just process liveness. The first one alone would have caught this incident
within minutes of it starting.

## Lessons

1. **Liveness probes that check process existence are insufficient for
 stateful network agents.** The BPF datapath can fail independently of the
 userspace process. You need an outcome-based health signal.

2. **Don't manage critical infrastructure with the tool that depends on it.**
 Flux + Cilium is a fine combination *until* you need to replace Cilium. At
 that moment, your reconciliation tool can't pull charts or resolve DNS,
 because both depend on the thing you're trying to fix. Have a non-GitOps
 recovery path for the CNI itself.

3. **Prefer outcome-based alerts to liveness-based alerts.** "Process is up"
 tells you almost nothing about whether the system is doing its job.
 "Packets are being dropped" or "endpoints aren't getting regenerated" are
 signals you can act on.

4. **Document the working recovery.** The cordon-drain-delete sequence above
 has been run multiple times now. Write it down. The next person hitting
 this, possibly you, in six months, will not remember.
