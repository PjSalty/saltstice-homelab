# Docmost

Self-hosted knowledge base / wiki. Replaces a Notion / Confluence
need. Postgres backend on iSCSI, Redis cache, OIDC SSO via Authentik.

Runs on `docs.example.com`. Internal only.

## Stack

- Docmost v0.25.x (current as of 2026-05)
- PostgreSQL 16 on iSCSI (RWO PVC, fsync semantics, same reasoning
 as every other Postgres in the homelab)
- Redis 7 for cache + queue
- Authentik OIDC (auto-provision users on first login)
- Wildcard TLS via cert-manager

## Deployment shape

Single-replica Deployment for the app, single-replica StatefulSet for
Postgres, Deployment for Redis. PDB on the app, no PDB on Postgres
because the deployment strategy is `Recreate` anyway (RWO PVC).

VPA Auto on every container. No HPA, workload is small and bursty
in a way HPA doesn't help with.

## Backup

Two paths:

- Velero schedule snapshots the PVCs nightly to SeaweedFS.
- A `pg_dump` CronJob runs a logical dump every 6 hours into the
 `pg-archives` SeaweedFS bucket. PITR-capable.

Restore drill is documented in the runbook.

## Network policy

Cilium CNP with default-deny. Allow:

- Ingress from `traefik` namespace on the app port.
- Ingress from `monitoring` namespace for metrics.
- Egress to `kube-system` DNS only.
- Egress to Authentik for OIDC callbacks.
- No internet egress, Docmost doesn't need any.
