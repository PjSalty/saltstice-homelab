# Vaultwarden

Self-hosted password manager. Uses the OIDCWarden fork because the
official `vaultwarden/server` doesn't support OIDC SSO yet.

Single-replica Deployment, iSCSI PVC for the SQLite database
(`/data`), CronJob nightly backup, Authentik SSO via the SSO env vars.

Version: v2025.10.3-1.

## Layout

```
vaultwarden/
├── README.md
├── kustomization.yaml
├── namespace.yaml
├── deployments/deployment.yaml
├── services/service.yaml
├── ingress/ingress.yaml
├── networkpolicy/cilium-networkpolicy.yaml
├── autoscaling/vpa.yaml
├── pdb/pdb.yaml
├── storage/pvc.yaml            , iSCSI PVC, 5Gi
└── backup/                     , nightly tar+gzip CronJob, 7-day retention
```

## SSO

`SSO_ENABLED=true`, `SSO_ONLY=false` so users can also use master
passwords if SSO is down. Authority is the homelab Authentik. Client
secret pulled from the `sso-client-secrets` Secret.

`SIGNUPS_ALLOWED=false`, invite-only via SSO group membership.

## RWO + Recreate

iSCSI volume = RWO. Deployment uses `strategy: Recreate`. Single
replica is fine for personal use; password manager outages aren't
a paging event.

## Required secrets

| Secret | Keys |
|---|---|
| `sso-client-secrets` | `VAULTWARDEN_CLIENT_SECRET` |
