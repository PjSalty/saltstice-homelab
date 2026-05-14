# security

Defense in depth across host, network, cluster, runtime, and supply
chain.

## Host

- Debian 13. Hardened by Ansible roles: kernel sysctl, sshd config,
 fail2ban, UFW, role-based sudo allowlists, unattended security
 upgrades.
- No password auth on SSH. Keys only. `automation` user for CI,
 `debian` for interactive.
- Proxmox cluster firewall on the bridge. UFW on every guest. Three
 layers, configured to coexist (see the bridge-nf incident).

## Cluster

- Pod Security Admission `restricted` on every namespace except a few
 documented exceptions (Semaphore needs root; specific init jobs
 documented in Kyverno exceptions).
- `runAsNonRoot: true`, `allowPrivilegeEscalation: false`,
 `capabilities.drop: [ALL]`, `seccompProfile: RuntimeDefault`.
 enforced by Kyverno admission, not just convention.
- ServiceAccount auto-mount disabled per workload unless required.
- Resource limits required on every container (Kyverno
 `require-resource-limits`).

## Network

- Default-deny ingress + egress at the cluster level
 (`default-deny.yaml`).
- Per-app CiliumNetworkPolicy with explicit allow lists. ~40 policies
 covering every namespace.
- Egress to internet allowed only for apps that need it (metadata
 fetchers, OIDC federation, SMTP). Default is no internet.
- DNS egress restricted to `kube-system / k8s-app=kube-dns`.
 `toCIDR: 0.0.0.0/0` does NOT match in-cluster Service VIPs because
 Cilium evaluates pre-DNAT.

## Runtime

- Falco modern-eBPF (no kernel module compilation). Falcosidekick
 routes events to AlertManager (warning+) and Loki (notice+).
- Custom rule for "shell in container" reduced to NOTICE so
 legitimate `kubectl exec` debug sessions don't page anyone, while
 still showing up in Loki for audit.
- Trivy operator scans every running image and every namespace's
 config. Kyverno `block-critical-vulnerabilities` keeps known-CRIT
 pods out of the cluster.

## Secrets

- SOPS-Age. Age key in cluster only, never on disk on workstations.
- External Secrets Operator pulls per-app secrets from a separate
 GitRepository so secret rotation doesn't trigger app reconciliation.
- Per-namespace SecretStore label selector, apps see only their own
 secrets.
- Kyverno `restrict-externalsecret-namespaces` blocks ExternalSecret
 creation in namespaces that don't have an explicit SecretStore.
- No secrets in commits, ever. Pre-commit hooks on every repo run
 gitleaks + custom PII patterns.

## Supply chain

- Container builds: SHA-tag immutable, Trivy gate on CRITICAL/HIGH,
 promotion to `:latest` only after scan green. Renovate watches
 upstream registries and opens MRs for version bumps.
- Harbor proxy for every upstream registry. Dockerfiles MUST reference
 the proxy paths, not upstream directly. Documented in
 [`docs/adrs/container-image-standard.md`](../docs/adrs/container-image-standard.md).
- Weekly rebuild schedule on every custom image picks up base-image
 CVE patches.

## Identity

- Authentik 2025.10 is the OIDC + SAML + forward-auth provider.
- Every web app uses SSO (OIDC native where supported,
 Traefik forward-auth proxy where not).
- Group-based authorization (`jellyfin-admins`, `platform-admins`,
 etc.). Group membership comes from Authentik flows, propagates to
 apps via OIDC `groups` claim.

## Audit + alert

- Cilium Hubble flow logs.
- K8s audit log shipped to Loki with PII filter.
- Falco events → AlertManager → Pushover for high-severity, Loki for
 the rest.
- cert-manager certificate expiry monitored (warn 30d, critical 14d).
