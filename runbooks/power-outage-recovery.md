# Power Outage Recovery Runbook

> First author: 2026-04-17, after a full-site power loss that exposed
> multiple compounding failure modes. This runbook is written from actual
> recovery, every step here cost real downtime.

## Fault model

When the entire rack loses power and comes back, the cluster restarts in
parallel instead of in dependency order. Several components assume a
clean dependency chain and fail in ways that cascade:

| Component | Failure on dirty stop | Blast radius |
|---|---|---|
| Traefik (CrowdSec plugin) | Plugin download from plugins.Traefik.io fails DNS (Cilium BPF identity cache not warm) → retry loop pegs CPU → liveness probe timeout → CrashLoopBackOff | Every `*.example.com` FQDN returns 503 externally; GitLab UI, Harbor UI, and downstream apps all appear offline |
| Harbor PostgreSQL | Admin `password` row hash gets truncated/rewritten; `project` rows for tenant projects lost (blobs remain on disk) | All Harbor robot accounts and admin basic-auth return 401 system-wide; any K8s workload with `imagePullPolicy: Always` crashes into ImagePullBackOff after its cached image ages out |
| Proxmox host | Runtime `ip route` to Traefik VIP is lost (only `/etc/network/interfaces` post-up is persistent, and pvedaemon keeps a stale source-address binding) | Proxmox OIDC "Connection refused" on callback, pvedaemon cannot reach Authentik |
| Authentik embedded outpost | `default` ServiceAccount with `automountServiceAccountToken: false` means the outpost controller can't create its Deployment/Service/Secret → every forward-auth FQDN 503 | docs, amp, alerts, HAProxy, vpn, K8s, NetBox all 503 |
| CrowdSec agent DaemonSet | Old machine registrations in LAPI block new agents (LAPI returns 403 "user already exists") | Agents stuck in CrashLoopBackOff; no IPS coverage |

## Recovery order (critical)

**Do these in order.** Parallelism is appealing, but each step unblocks
the next, running out of order wastes time chasing symptoms of the
earlier blocker.

### 1. Restore Traefik VIP

Without Traefik, nothing else you do via `*.example.com` will
work. K8s node IPs `10.x0.10–22` stay reachable directly, use them.

```bash
ssh debian@10.x0.10
export KUBECONFIG=/etc/rancher/rke2/rke2.yaml
sudo -E /var/lib/rancher/rke2/bin/kubectl -n traefik get pods
# Expect CrashLoopBackOff. Check logs for plugin download errors.
sudo -E /var/lib/rancher/rke2/bin/kubectl -n traefik logs <pod> --tail 50 | grep -i plugin
```

If the CrowdSec plugin is the cause, apply the emergency bypass (and
track a permanent fix as a follow-up, see *Hardening*):

- Comment out the `experimental.plugins.crowdsec-bouncer` block in
 `infrastructure/controllers/traefik/values.yaml`
- Merge; then force HelmRelease re-render with matching
 `reconcile.fluxcd.io/requestedAt` + `reconcile.fluxcd.io/forceAt`
 annotations on the HelmRelease.

Verify from outside the cluster: `ping <internal-ip>` and
`curl -sI https://gitlab.example.com`.

### 2. Restore Harbor auth

```bash
# 2a. Restart the Harbor stack on the VM (compose is at /opt/harbor)
ssh debian@<internal-ip>
sudo bash -c 'cd /opt/harbor && docker compose restart'

# 2b. Check if admin password survived
curl -sk -u admin:<HARBOR_ADMIN_PASSWORD from harbor.yml> \
  https://harbor.example.com/api/v2.0/users/current
# If 401, admin password hash may be corrupted. Reset from the env var:
ssh debian@<internal-ip>
sudo docker exec harbor-db psql -U postgres -d registry \
  -c "-- redacted --
sudo docker restart harbor-core
# Core re-initializes admin password from HARBOR_ADMIN_PASSWORD env var.

# 2c. Check auth_mode
sudo docker exec harbor-db psql -U postgres -d registry \
  -c "SELECT v FROM properties WHERE k='auth_mode';"
# Expected: oidc_auth. Admin basic-auth still works as a local fallback.

# 2d. Check that all projects still exist
sudo docker exec harbor-db psql -U postgres -d registry \
  -c "SELECT name FROM project WHERE deleted=false;"
# If a project (e.g. example-app) is missing from DB but exists on disk
# under /data/harbor/data/registry/docker/registry/v2/repositories/,
# re-create the project via API:
curl -sk -u admin:<pw> -X POST https://harbor.example.com/api/v2.0/projects \
  -H 'Content-Type: application/json' \
  -d '{"project_name":"example-app","public":false,"storage_limit":-1}'
```

### 3. Re-import existing Harbor blobs (if a project was lost)

When a project disappears from Harbor's DB but the registry blob store
on disk is intact, Harbor returns 404 for every tag even though the
bytes are there. Re-push the manifests to repopulate the metadata.

Walkthrough for one repo:

```bash
# On the Harbor VM, with admin creds:
BLOBDIR=/data/harbor/data/registry/docker/registry/v2/blobs/sha256
REPO=example-app/example-image
TAG=8.0.6-rhel8
# Read the tag's current manifest digest
DIGEST=$(sudo cat /data/harbor/data/registry/docker/registry/v2/repositories/$REPO/_manifests/tags/$TAG/current/link | sed 's|sha256:||')
# Walk the manifest, upload every referenced blob via the Docker
# Registry v2 protocol (POST /v2/repo/blobs/uploads/ → PUT with digest)
# then finally PUT the manifest at /v2/repo/manifests/$TAG.
```

There is a helper script checked into `infrastructure/homelab-scripts`
called `reimport-harbor-project.sh`, see the 2026-04-17 recovery
transcript.

### 4. Restore the Harbor pull secret

When you re-create a robot account via Harbor API, Harbor generates a
new secret and **ignores** the `secret` field in the request body. Copy
the new token out of the creation response, then update the SOPS file
at `infrastructure/secrets/kubernetes/flux-system/harbor-pull-secret.yaml`
and push. Kyverno re-syncs every namespace automatically, but
existing cloned secrets may cache the old value, force Kyverno to
re-clone by `kubectl -n <ns> delete secret harbor-pull-secret`.

### 5. Restore the Proxmox static route

```bash
ssh root@<mgmt-ip>
# Source IP must be on VLAN 30 so MikroTik conntrack doesn't see
# asymmetric return paths
ip route replace <host>/32 via 10.x0.10 dev vmbr1.30 src 10.x0.100
systemctl restart pvedaemon
```

This is already codified in the `proxmox` Ansible role at
`roles/proxmox/tasks/main.yml`, re-running the role is the idempotent
fix.

### 6. Fix the Authentik outpost

The embedded outpost controller runs in the `authentik-worker` pod. It
needs an in-cluster ServiceAccount with permissions to create its
own `Deployment`, `Service`, `Secret`, and `ConfigMap`. This was codified
in `apps/authentik/base/rbac/serviceaccount.yaml`
(namespace-scoped Role, not cluster-scoped).

If the outpost's `service_connection` is `None`, create a local
`KubernetesServiceConnection` and bind it via `ak shell`:

```python
from authentik.outposts.models import KubernetesServiceConnection, Outpost
conn = KubernetesServiceConnection.objects.filter(local=True).first() or \
       KubernetesServiceConnection.objects.create(name="Local Kubernetes Cluster", local=True)
o = Outpost.objects.get(name="authentik Embedded Outpost")
o.service_connection = conn
# Also re-associate all ProxyProvider objects; forward-auth is useless
# without providers attached:
from authentik.providers.proxy.models import ProxyProvider
for p in ProxyProvider.objects.all():
    o.providers.add(p)
o.save()
```

### 7. Prune stale CrowdSec machines

```bash
K="sudo -E KUBECONFIG=/etc/rancher/rke2/rke2.yaml /var/lib/rancher/rke2/bin/kubectl"
# Delete every agent machine registration (agents will re-register)
$K -n crowdsec exec deploy/crowdsec-crowdsec-lapi -- \
  cscli machines list -o json \
  | python3 -c 'import json,sys; [print(m["machineId"]) for m in json.load(sys.stdin) if m["machineId"].startswith("crowdsec-crowdsec-agent-")]' \
  | xargs -I{} $K -n crowdsec exec deploy/crowdsec-crowdsec-lapi -- cscli machines delete {}
$K -n crowdsec rollout restart daemonset/crowdsec-crowdsec-agent
```

## Hardening (so this never happens again)

### H1. Don't depend on Internet DNS during Traefik startup

The CrowdSec bouncer plugin is downloaded from `plugins.traefik.io` on
every pod start. If Cilium identity cache hasn't warmed, that DNS
returns EPERM and Traefik retries in a loop that kills its liveness
probe. Options:

1. **Bake the plugin into a pinned image.** Build a Traefik image with
 the plugin already present at `/plugins-storage/...` and pin that
 image in values. No runtime network access needed.
2. Add an explicit `CiliumNetworkPolicy` egress rule allowing the
 Traefik pods to talk to `plugins.traefik.io` on 443/TCP and to
 kube-DNS for its resolution. (Even with this, i still fail closed
 if the internet is down on bring-up.)

Option 1 is the robust choice. Tracked as a follow-up MR.

### H2. Back up Harbor's PostgreSQL, not just the filesystem

My Harbor backup currently snapshots the registry storage volume but
NOT the Harbor-internal PostgreSQL database. That's why the blobs on
disk survived but the admin password hash and project metadata did
not, they only existed in Postgres.

Action: add a nightly `pg_dump` of every Harbor database to backup
storage, and verify the dumps via `pg_restore --list` in the Velero
verify job.

### H3. Make the Proxmox VIP route reboot-safe

The runtime `ip route replace` is applied by Ansible during `proxmox`
role runs and doesn't survive reboots. The line is added to
`/etc/network/interfaces` with `post-up`, which DOES survive reboots.
but only if the interface comes up cleanly. When the K8s side isn't
ready yet (power-on race), the post-up can fail silently.

Action:

- Add a `systemd` oneshot that retries `ip route replace ...` with
 `ExecStartPost` until ping <internal-ip> succeeds, and order it
 `Before=pvedaemon.service`.
- Add a node_exporter textfile collector that exports the route state
 so i alert if the Traefik VIP ever becomes unreachable from Proxmox.

### H4. Authentik outpost RBAC is now in git

Fixed in `apps/authentik/base/rbac/serviceaccount.yaml` (MR
infrastructure/homelab-Kubernetes!650, 2026-04-17). The worker now
uses a dedicated `authentik` ServiceAccount with a namespace-scoped
Role. The outpost will reconcile on its own next time.

### H5. CrowdSec machine registration TTL

LAPI keeps old agent registrations forever, every pod churn (VPA,
rolling restart, outage recovery) adds another stale machine, and
eventually the "user already exist" 403 blocks new agents.

Action: enable LAPI's built-in heartbeat pruning, or add a CronJob that
calls `cscli machines prune --duration 168h --force` weekly.

### H6. A hot standby power source wouldn't hurt

The rack lost power cleanly (ordered shutdown) last time i planned
for it, and dirtily (bad) this time. A UPS with `apcupsd` or
`nut-client` + `systemctl poweroff` on low battery would have
converted this into a graceful shutdown, avoiding every step above.

## Post-recovery validation

```bash
# All SSO-integrated services respond
for fqdn in app auth gitlab harbor jellyfin grafana; do
  curl -sk -o /dev/null -w "%{http_code} ${fqdn}.example.com\n" \
    "https://${fqdn}.example.com"
done
# Expect 200/302 on each

# Proxmox OIDC backchannel reaches Authentik
curl -sk -o /dev/null -w "%{http_code} proxmox OIDC discovery\n" \
  https://auth.example.com/application/o/proxmox/.well-known/openid-configuration
# Expect 200

# Tenant app api+web Ready
kubectl -n example-app get pods -l 'app.kubernetes.io/component in (api,web)'

# Harbor health
curl -sk https://harbor.example.com/api/v2.0/health | jq '.status'
# Expect: "healthy"

# Traefik VIP reachable from Proxmox
ssh root@<mgmt-ip> 'ping -c 1 <internal-ip> && ip route show <internal-ip>'
```
