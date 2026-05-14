# Why per-chart Helm `image.registry` overrides don't work

**Date:** 2026-04-09
**Impact:** 18 pods stuck in `ImagePullBackOff` after a Helm chart batch update tried to route all pulls through a private registry.

## Summary

The plan was simple: set `image.registry: harbor.example.com/dockerhub-proxy`
on every HelmRelease and route all upstream container pulls through the
internal Harbor proxy. Eighteen pods landed in `ImagePullBackOff` immediately
because the resulting image references looked like
`harbor.example.com/dockerhub-proxy/quay.io/jetstack/trust-manager`, a double
prefix that no registry serves.

## Root cause

Helm charts construct image references differently. There is no agreed
contract for what `image.registry` means. Three variants are common:

```yaml
# Variant A, most common
image: "{{ .Values.image.registry }}/{{ .Values.image.repository }}:{{ .Values.image.tag }}"

# Variant B, registry is part of repository
image: "{{ .Values.image.repository }}:{{ .Values.image.tag }}"
# (where .Values.image.repository is "registry.io/path/image")

# Variant C, registry is split, repository is just the name
image: "{{ .Values.image.registry }}/{{ .Values.image.repo }}/{{ .Values.image.name }}:{{ .Values.image.tag }}"
```

Setting `image.registry` to your proxy works correctly for Variant A. For
Variant B, you've now prepended your proxy to a string that already contains
the upstream registry name, producing the double-prefix. For Variant C,
depending on which sub-key you wrote to, you get a different broken result.

There is no way to write a single override that works for all three.

## Fix

Move the registry rewriting **down a layer**, to the container runtime,
where it can transparently rewrite any pull regardless of how the chart
constructed the image string.

For RKE2 / containerd: `/etc/rancher/rke2/registries.yaml` on every node.

```yaml
mirrors:
  docker.io:
    endpoint:
      - "https://harbor.example.com/v2/dockerhub-proxy"
  ghcr.io:
    endpoint:
      - "https://harbor.example.com/v2/ghcr-proxy"
  quay.io:
    endpoint:
      - "https://harbor.example.com/v2/quay-proxy"
```

Now charts can write whatever image string they want. Containerd sees the pull
intent for `docker.io/library/postgres:16` and silently fetches it from the
proxy. Zero manifest changes.

## Lessons

1. **Helm chart authors don't share a contract.** `image.registry` means
 different things in different charts. Any approach that requires per-chart
 override logic is a maintenance treadmill.

2. **The container runtime is the right layer for registry policy.** It sees
 every pull, regardless of how the manifest got constructed. One config,
 applied once, covers every workload past, present, and future.

3. **Debugging path that worked: look at the resulting image string.**
 `kubectl describe pod` showed `harbor.example.com/dockerhub-proxy/quay.io/...`
 immediately. The double prefix was the smoking gun.
