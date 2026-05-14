# UPS + auto-recovery, design of record

> Drafted after the 2026-04-17 power-loss incident. Plan, not yet
> set up end-to-end. The runbook for the manual recovery that
> motivated this lives at `runbooks/power-outage-recovery.md` (private).

## Context

A full-site power loss exposed compounding bring-up failures: Traefik
plugin DNS race, Harbor Postgres hash corruption, Proxmox VIP route
loss, Authentik outpost RBAC, stale CrowdSec machines. Manual recovery
took hours. This plan replaces that with graceful shutdown and
deterministic boot order.

## Hardware

Tripp Lite SMART1500LCD, 1500VA / 900W, 2U rack mount, USB + serial
monitoring. Supported by NUT via the `tripplite_usb` driver. Runtime
at expected ~300W load: 10–15 minutes, ample margin for the cascade
below.

## Architecture

```
  UPS  ──USB──▶  Proxmox host                            (NUT primary)
                    │
                    │ upsd on infra VLAN:3493
                    │
                    ▼
         ┌──────────┴──────────────────────────┐
         │ NUT secondaries (one per VM):       │
         │   truenas, haproxy-1/2,             │
         │   k8s-master-1..3, k8s-worker-1..3, │
         │   gitlab, harbor, netbox, amp,      │
         └──────────┬──────────────────────────┘
                    │ (each runs upsmon in SECONDARY role)
                    ▼
          On LOW BATTERY event:
          ├── Tier 1 wait (20s):  K8s workers drain + shut
          ├── Tier 2 wait (60s):  K8s masters shut
          ├── Tier 3 wait (90s):  HAProxy + gitlab/harbor/netbox/amp shut
          ├── Tier 4 wait (120s): TrueNAS shuts (ZFS flushes)
          └── Tier 5 wait (150s): Proxmox host halts
```

Total cascade: ~2.5 minutes. Cold boot reverses this via Proxmox
`startup` ordering.

## Shipping plan, in order of impact

### 1. Pre-bake Traefik CrowdSec plugin (highest ROI, no UPS needed)

Build a Traefik image with the plugin already unpacked at
`/plugins-storage/...`. Removes the `plugins.traefik.io` runtime DNS
dependency that stalled bring-up. Pin that image in
`infrastructure/controllers/traefik/values.yaml`. This single change
removes the biggest failure from the 2026-04-17 incident.

### 2. Harbor `pg_dump` in backups (second highest ROI, no UPS needed)

Current Harbor backup snapshots the registry storage volume but NOT
the internal Postgres. Blobs on disk survived; the admin password hash
and project metadata didn't. Add a nightly `pg_dump` of every Harbor
database to backup storage; verify via `pg_restore --list` in the
Velero verify job.

### 3. NUT server role on Proxmox (primary UPS owner)

- `homelab-ansible/roles/nut-server/`
- `nut` package, `ups.conf` with `tripplite_usb` driver
- `upsmon.conf` as PRIMARY; `SHUTDOWNCMD` triggers the ordered
 cascade script
- Listen on `0.0.0.0:3493`, firewall to infra + K8s VLANs only
- Start with Proxmox-only: `upsmon -c fsd` with VMs powered off,
 confirm Proxmox halts cleanly

### 4. NUT client role on every VM

- `homelab-ansible/roles/nut-client/`
- Each VM: `nut-client`, point at Proxmox UPS, `upsmon` SECONDARY
- Per-tier shutdown logic:
 - Workers: `kubectl drain` self, then shutdown
 - Masters: graceful kube-apiserver stop, make sure etcd quorum, shutdown
 - HAProxy / GitLab / Harbor / NetBox / amp: stop service, sync, halt
 - TrueNAS: ZFS export pools, halt
- Tier value baked into `host_vars` so Ansible inventory remains the
 source of truth

### 5. Proxmox `startup` ordering via Terraform

- `startup_order` variable on `modules/vm/`
- Tier 1 (cold boot first): TrueNAS
- Tier 2: HAProxy pair
- Tier 3: K8s masters (3 in parallel)
- Tier 4: K8s workers (3 in parallel)
- Tier 5: Aux VMs (GitLab, Harbor, NetBox, AdGuard, amp, ci-runner,
- `qm set <id> --startup order=N,up=S,down=S`
- Reverses the shutdown cascade for deterministic cold boot

### 6. Self-heal systemd units (belt and suspenders)

- `proxmox-traefik-route.service` on Proxmox: retries the VIP
 route until it pings, then restarts `pvedaemon`. Oneshot,
 `Before=pvedaemon.service`.
- `harbor-verify.service` on the Harbor VM: post-boot consistency
 check on Postgres (admin `password` column length, expected
 `project` rows). Fires an alert on drift.
- CrowdSec machine-prune CronJob inside K8s, weekly:
 `cscli machines prune --duration 168h --force`.

### 7. Testing matrix (gate before declaring done)

UPS shutdown is famously "works in theory, fails in prod." Test in
this exact order; each step gates the next.

1. **Dry run on Proxmox only**, `upsmon -c fsd` with VMs powered
 off. Verify Proxmox halts cleanly.
2. **Single test VM**, bring one disposable VM up as a NUT
 secondary, trigger `fsd`, confirm it shuts before Proxmox.
3. **Tier-by-tier addition**, add workers, then masters, then
 HAProxy, then TrueNAS. Re-test `fsd` after each tier.
4. **Real power pull**, pull UPS wall plug after the full cascade
 is configured. Watch the whole thing drain end-to-end.
5. **Cold boot test**, plug back in, confirm Proxmox `startup`
 ordering brings everything up and Flux reconciles with no manual
 intervention.
6. **Document quarterly test**, `runbooks/ups-shutdown-test.md` so
 the cascade still works after inventory churn.

## Repo touch points

| Repo | Paths |
|---|---|
| `homelab-ansible` | `roles/nut-server/`, `roles/nut-client/` |
| `homelab-terraform` | `modules/vm/`, `startup_order` variable |
| `homelab-kubernetes` | Pre-baked Traefik image; CrowdSec machine-prune CronJob |
| `homelab-docs` | `runbooks/ups-shutdown-test.md` (quarterly test) |

## Risks and trade-offs

- **The cascade script is the scariest part.** One bug and a future
 outage drops things in the wrong order (storage before masters →
 etcd corruption). The test matrix above is not optional.
- **NUT USB driver reliability.** The `tripplite_usb` driver has had
 historical regressions; pin a known-working NUT version and verify
 `upsc` returns sane values before trusting shutdown to it.
- **Partial-failure mode.** If one secondary fails to shut (crashed
 upsmon, network blip), the primary should still halt on time.
 `FINALDELAY` is a hard deadline, not a polite ask.
- **UPS battery ages.** Battery replacement at year 3 or whenever
 `upsc` reports degraded runtime. RBC-series, user-replaceable.

## Deferred

- Should Harbor VM restart be tied to the graceful shutdown cascade
 or remain standalone? Current plan: include it. Less risk of dirty
 DB stops.
- Second UPS for network gear (router + switches) to decouple from
 the server rack? Out of scope; revisit if runtime ever becomes tight.
- Proxmox host power-on: rely on wall power restoration vs. IDRAC
 auto-power-on? Current plan: iDRAC "Last Power State = ON".
