# Runbooks

Operational procedures. Each one is the actual sequence run when the
condition triggers.

| Runbook | When to use |
|---|---|
| [Cilium-silent-degradation-recovery](cilium-silent-degradation-recovery.md) | Cilium agent passes liveness but datapath broken |
| [restore-from-Velero](restore-from-velero.md) | Recover a namespace, PVC, or cross-namespace clone |
| [rotate-an-ESO-secret](rotate-an-eso-secret.md) | Rotate any ESO-managed credential |
