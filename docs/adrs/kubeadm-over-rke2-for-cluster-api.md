# ADR: kubeadm over RKE2 for Cluster API

**Status:** Accepted. Supersedes
[rke2-over-vanilla-kubeadm](rke2-over-vanilla-kubeadm.md) for new clusters
only. RKE2 keeps running the existing cluster until the last workload
leaves it.

## Context

Rebuilding cluster lifecycle on Cluster API, with Proxmox as the
infrastructure provider (CAPMOX, `ionos-cloud/cluster-api-provider-proxmox`).
That means picking a bootstrap and control plane provider, which means
picking a distribution again.

Assessed six: kubeadm, RKE2, Talos, k0s via k0smotron, k3s, MicroK8s.
Backed by a five-strand research pass on 2026-08-08, all five now
resolved. The fifth, CVE response time, reported on 2026-08-19 and is
folded in below.

## Decision

kubeadm, via the in-tree providers CABPK and `KubeadmControlPlane`.

## Reasoning

The old ADR called this trigger itself: "Multi-cluster fleet at scale →
vanilla kubeadm + Cluster API for the lifecycle abstraction." That is the
condition arriving. This is the old decision retiring on its own terms,
not a reversal of it.

What settles it is the provider, not the distribution.

- CAPMOX ships 13 cluster templates. All 13 use `KubeadmControlPlane`.
 Its e2e CI declares exactly one bootstrap and one control plane
 provider: kubeadm. Nothing else is exercised.
- Adoption on CAPMOX: kubeadm has 72 code hits plus commercial use
 (Giant Swarm). Talos has 11 repos despite being unsupported. RKE2 has
 two confirmed users, both found via bug reports, no docs on either
 side. CAPRKE2's own docs cover AWS, vSphere and Docker. Proxmox is
 never mentioned.
- CAPMOX v0.8.0 stopped populating `ProxmoxMachine.status.addresses`.
 Talos broke (#710) and RKE2 broke (#714), filed a day apart. RKE2's
 bootstrap controller looped on "No ControlPlane IP Address found for
 node registration" and blocked every rolling update. kubeadm was
 unaffected, because kubeadm is what CAPMOX tests. Fixed in v0.8.1.

Rebuild-from-scratch is the whole point of moving to Cluster API, so it
has to sit on the pairing that CAPMOX regressions do not break.

Three smaller reasons. Version ownership: the estate just demonstrated
it. containerd 2.2 goes EOL 2026-11-06 and only RKE2 1.36 carries 2.3
LTS, so clearing the runtime deadline required a Kubernetes minor
upgrade. It landed cleanly on 2026-08-19, v1.36.3+rke2r1 with containerd
`2.3.3-k3s1`. The upgrade was right; the point is that it was the only
lever. On RKE2 the runtime version and the Kubernetes version are one
decision. On kubeadm the runtime comes from the node image and i pin it
independently. Governance: Cluster API is a Kubernetes SIG subproject, so no
vendor can relicense it. RKE2, Talos and MicroK8s are not CNCF projects
at all. Contract risk: Cluster API drops the v1beta1 contract in v1.16,
and CABPK defines that contract rather than chasing it.

Capacity is not a reason either way. The lightweight distributions are
not measurably lighter in RAM, on the only independent numbers that
exist, and both of those measure k3s.

## What does not carry over

The old ADR named two RKE2 conveniences. Both are now work, not rhetoric.

- `system-default-registry` pointed every node at the Harbor proxy in
 one setting. That becomes containerd registry mirrors baked into the
 node image.
- `HelmChartConfig` is an RKE2-only CRD, and
 [`infrastructure/cilium/`](../../infrastructure/cilium/) uses it today.
 Cilium gets installed a different way on the new clusters.

`lablabs.rke2` and `k8s-prereqs` get no further investment, but they do
not disappear on merge. They keep driving the existing cluster,
including its 1.36 upgrade, until it drains. Both paths run at once for
most of the rebuild, and that is an accepted cost.

## What i gave up

Roughly 106 CIS controls, in Sections 1 through 4, become mine. Kyverno
in Enforce, NetworkPolicy on every application namespace, PSA labels,
Trivy and SOPS already cover Section 5, about 40 of 146. The rest was
the distribution's opinion and is now mine to form.

Encryption at rest. RKE2 and Talos turn it on automatically, kubeadm
does not. Build it.

Scheduled etcd snapshots, twice daily with S3 upload. Best default
backup story of anything assessed. Build it.

Audit logging. Nothing is lost against RKE2, because its policy was
`rules: [{level: None}]`, but nothing is gained either. Build it in the
same batch as the two above.

Certificate rotation and etcd maintenance.

## What argues the other way

RKE2's CIS hardening is partly fiction: with `profile: cis` set, the
generated audit policy logs nothing while CIS 1.2.22 to 1.2.25 pass.
SUSE documents this under "Operator Intervention Required". That cuts
toward kubeadm, but only by shrinking what RKE2 was actually giving.

Talos has roughly five times RKE2's real CAPMOX adoption. It stays
ruled out on the old ADR's grounds, plus Sidero Metal is discontinued
and its control plane provider is still v1alpha3.

CVE response time is now measured rather than open, and it splits in
two directions.

For Kubernetes CVEs kubeadm is the fastest option available and every
bundler is structurally slower, because RKE2, k3s and k0s compile
Kubernetes into their own binary and cannot ship a fix until they
respin. On CVE-2025-5187 that cost RKE2 10 days, k3s 12 and k0s 8.
kubeadm takes the upstream patch release on day zero. That holds for
every future Kubernetes CVE.

For runtime CVEs the answer is not about distributions at all, it is
about where the node image gets containerd. RKE2 lagged 15, 36, 52 and 7
days across four runtime CVEs, so it is not uniformly fast even on what
it bundles, and Talos beat it on all four. But Debian trixie's own `runc`
package still carries the November 2025 container escape trio 276 days
on, and its `containerd` is still exposed to a Critical host-root
execution CVE. Built that way a kubeadm node is the worst option
measured. Built on Docker's `containerd.io`, which packages 2.3.3 for
trixie today and pins runc 1.4.3, it is ahead of RKE2.

So the finding is a build constraint, recorded here because it is the
kind that goes wrong quietly: **the node image must not take containerd
or runc from Debian.** Track them upstream and point Renovate at that
source.

One thing genuinely argues the other way: only Talos publishes a
fix-delivery commitment, and it is not paywalled. RKE2 and k0s publish
acknowledgement targets with no remediation SLA at any tier.

## When i would reconsider

- Cluster API adds a first-class Proxmox path for another distribution
 → re-run the comparison, the provider argument is the load-bearing one.
- The CIS Sections 1 to 4 work stalls → a hardened distribution buys
 back real time.
- Single cluster forever, no fleet → the old ADR was right and this one
 is overhead.
