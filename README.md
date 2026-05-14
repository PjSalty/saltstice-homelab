# saltstice-homelab

Production homelab on Proxmox. IaC, K8s manifests, decision records,
incident write-ups. Modeled after the homelab-repo pattern (vehagn,
onedr0p, bjw-s) but pushed harder on *why* and *what broke*.

## Stack

| Layer | What |
|---|---|
| Hypervisor | Proxmox VE on Dell R740xd, ZFS mirror, RTX A2000 passthrough |
| OS | Debian 13 |
| Kubernetes | RKE2, 3 control-plane + N workers (Karpenter-scaled) |
| CNI | Cilium 1.x, kube-proxy replacement, BGP MD5 to MikroTik, Hubble |
| LoadBalancer | MetalLB, BGP-advertised |
| Ingress | Traefik with Authentik forward-auth |
| Identity | Authentik 2025.10 |
| Storage CSI | democratic-CSI (TrueNAS iSCSI for RWO, NFS for RWX) |
| GitOps | Flux v2 multi-source |
| Secrets | SOPS-Age + External Secrets Operator |
| Backup | Velero, Kopia uploader, in-cluster SeaweedFS S3 |
| Policy | Kyverno, Cilium NetworkPolicy |
| Runtime security | Falco modern-eBPF + Falcosidekick |
| Image registry | Harbor with proxy caches |
| Observability | Prometheus, Grafana, Loki, Tempo, AlertManager → Pushover |
| Network | MikroTik RB4011 + CRS317 + CRS328, four VLANs |
| NAS | TrueNAS SCALE, ZFS, iSCSI + NFS |
| IaC | Terraform (Proxmox + cloud), Ansible (host + day-2) |
| CI/CD | self-hosted GitLab, reusable templates, Renovate |

## Layout

```
apps/               , per-application K8s manifests
infrastructure/     , cluster-wide (CNI, ingress, autoscaling, backup)
networking/         , VLANs, BGP, MetalLB, MikroTik
storage/            , TrueNAS, ZFS, iSCSI/NFS, SeaweedFS
observability/      , metrics, logs, traces, alerts
security/           , Kyverno, Cilium policies, Falco
ci/                 , GitLab CI templates, Renovate
terraform/          , VM modules, cloud providers
ansible/            , host hardening, day-2 ops
incidents/          , postmortems
docs/adrs/          , architecture decision records
tools/              , local helpers (redaction, etc.)
```

Long-form posts at [saltstice.com](https://saltstice.com).
