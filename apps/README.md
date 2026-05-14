# apps

Per-application Kubernetes manifests. Each directory has its own
README, Helm/Kustomize layout, NetworkPolicy, autoscaling, PDB.

## Deployed

| App | Namespace | Stateful | SSO | Public |
|---|---|---|---|---|
| Authentik | Authentik | yes (Postgres) |, (it IS the SSO) | no |
| Vaultwarden | Vaultwarden | yes (SQLite) | OIDC via Authentik | no |
| Jellyfin | media | yes (SQLite + media) | OIDC via Authentik | yes (NAT) |
| Docmost | Docmost | yes (Postgres + Redis) | OIDC via Authentik | no |
| Headlamp | Headlamp | no | OIDC via Authentik | no |
| NetBox | NetBox | yes (Postgres) | OIDC via Authentik | no |
| Harbor | (VM, not K8s) | yes | OIDC via Authentik | no |
| GitLab | (VM, not K8s) | yes | OIDC via Authentik | no |
| AdGuard | (VM, not K8s) | yes | basic auth (Traefik) | no |
| Semaphore | Semaphore | yes (Postgres) | forward-auth via Authentik | no |
| ntfy | ntfy | no | basic auth | no |
| AMP | amp | yes (game state) | OIDC via Authentik | yes (game ports) |
| UniFi controller | UniFi | yes (mongo) | basic auth | no |
| WireGuard | vpn | no | preshared keys | yes (UDP) |
| Cloudflared | external-DNS | no |, |, |

## Pattern per app

```
apps/<app>/
├── README.md                 , what's here, why this shape, secrets needed
├── kustomization.yaml
├── namespace.yaml
├── deployments/              , Deployment or StatefulSet
├── services/
├── ingress/                  , Traefik IngressRoute, with middleware chain
├── networkpolicy/            , Cilium CNP, default-deny + explicit allow
├── autoscaling/              , VPA Auto, HPA where stateless and bursty
├── pdb/                      , PDB excluding Job pods
├── storage/                  , PVC + PV definitions, iSCSI vs NFS chosen per workload
├── backup/                   , pg_dump CronJob etc., where applicable
└── jobs/ or configs/         , setup jobs, ConfigMaps
```

## SSO integration

Every app with a UI integrates through Authentik. The pattern:

1. Add the app to `authentik/configmaps/sso-credentials.yaml`
 (client ID + redirect URI).
2. The `sso-complete-setup` Job creates the OAuth2 provider +
 application in Authentik via API.
3. The app's deployment env vars reference `sso-client-secrets`
 for the actual client secret.
4. For apps without OIDC support, use Traefik forward-auth pointing
 at the Authentik embedded outpost.

## Storage choice per app

iSCSI block (RWO) for anything with a database. NFS (RWX) for
shared-read content (Jellyfin media). See
[`storage/README.md`](../storage/README.md) for why and when.

## Autoscaling rule

Every Deployment / StatefulSet has a VPA in Auto mode. Stateless
bursty apps (Authentik server, Traefik) also get HPA, with the VPA
limited to memory only via `controlledResources: ["memory"]` so HPA
and VPA don't fight over CPU.

## Rate limit on every IngressRoute

Default Traefik middleware chain includes rate limiting (100/s,
burst 50). Stricter `rate-limit-strict` (10/s) is available but had
to be backed off Authentik because the SPA loads ~30 JS chunks
concurrently.
