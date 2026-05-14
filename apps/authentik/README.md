# Authentik

Self-hosted SSO. OIDC + SAML + forward-auth proxy. Every other app in
the cluster authenticates through this.

Version: 2025.10.2.

## Components

- **server**, HTTP + UI + embedded forward-auth outpost. HPA scales
 1-3 replicas on CPU.
- **worker**, background tasks (flow execution, system tasks). One
 replica.
- **PostgreSQL**, StatefulSet with NFS-backed PV. SCRAM-SHA-256.
 postStart hook tunes `work_mem`, `random_page_cost`, disables JIT.
 Sidecar: `postgres-exporter` for Prometheus.
- **Redis**, session cache + task queue. Read-only rootfs, non-root
 UID. Sidecar: `redis-exporter`.

PostgreSQL backups via `pg_dump` CronJob nightly (7-day retention) to
a separate NFS PVC.

## Layout

```
authentik/
├── README.md
├── kustomization.yaml
├── namespace.yaml
├── deployments/                , server, worker, postgresql, redis
├── ingress/ingress.yaml        , Traefik websecure, default-chain-with-ratelimit
├── networkpolicy/              , Cilium CNP
├── autoscaling/
│   ├── hpa.yaml                , server HPA (CPU 70%, 1-3 replicas)
│   └── vpa.yaml                , VPAs for server (memory-only), worker, postgres, redis
├── pdb/pdb.yaml                , server + worker, minAvailable=1
├── backup/                     , pg_dump CronJob + 2Gi NFS PVC
├── jobs/                       , SSO-provider setup jobs (one per integrated app)
└── configmaps/                 , OIDC client IDs and redirect URIs (no secrets)
```

## SSO setup is in code

The OIDC providers, applications, and their redirect URIs are defined
in a single `sso-credentials` ConfigMap and reified by a `sso-complete-setup`
Job that hits the Authentik API at startup. Adding a new integrated
app means: one ConfigMap entry plus a redirect URI in the app's
deployment. No clicking around in the Authentik UI.

The `semaphore-proxy-provider` Job is a separate path because Semaphore
needs forward-auth instead of OIDC; that Job creates a Proxy Provider
in `forward_single` mode and binds it to the embedded outpost.

Client secrets and the API token live in the SOPS-encrypted `secrets`
repo.

## HPA + VPA together

Server gets both:
- HPA scales replicas on CPU (1-3, target 70%, asymmetric stabilization
 windows: 120s scale-up, 600s scale-down)
- VPA in Auto mode but `controlledResources: ["memory"]` so it doesn't
 fight HPA over CPU. Adjusts memory requests/limits as the workload
 shifts.

Worker, Postgres, Redis all get plain VPA Auto with both CPU and memory.

## Probe tuning that matters

Server liveness: 30s initial delay, 15s period, 3 failure threshold.
Readiness: 15s initial, 30s period, 5 failures. Startup: 15s initial,
10s period, 18 failure threshold (allows up to 3 minutes for cold
start during outpost discovery).

`AUTHENTIK_WEB__TIMEOUT=60` because the embedded outpost reload can
take 30-40s under load and the default 30s timeout was killing
in-flight requests.

`AUTHENTIK_WEB__WORKERS=6` for concurrent request handling. Default
is 2 which bottlenecks the SPA's ~30 concurrent JS chunk loads.

## Rate limit pitfall

The Traefik middleware chain uses `default-chain-with-ratelimit`
(100/s, burst 50), not the stricter `default-chain-with-strict-ratelimit`
(10/s). Authentik's SPA loads ~30 JS chunks concurrently on first paint;
10/s killed the page render with 429s.

## Cookie domain

`AUTHENTIK_COOKIE_DOMAIN=example.com`, cookies share across
every subdomain in the homelab so SSO works seamlessly across all
integrated apps.

## Required secrets (from `infrastructure/secrets`)

| Secret | Keys |
|---|---|
| `authentik-secret` | `AUTHENTIK_POSTGRESQL__PASSWORD`, `AUTHENTIK_SECRET_KEY` |
| `authentik-admin` | `password`, `email` |
| `sso-client-secrets` | `AUTHENTIK_API_TOKEN`, plus per-app client secrets |
