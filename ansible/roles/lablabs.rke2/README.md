# lablabs.RKE2

Vendored Ansible role for deploying RKE2 (Rancher Kubernetes Engine 2) clusters. This is a third-party role from [lablabs/Ansible-role-RKE2](https://github.com/lablabs/ansible-role-rke2), included directly in the repository for reliability and version control.

## Overview

This role handles the full lifecycle of an RKE2 cluster:
- First server node initialization
- Additional server (control plane) node joining
- Agent (worker) node joining
- Kubeconfig download
- Rolling restart support
- Optional keepalived and kube-VIP integration

## Key Configuration (from group_vars/k8s_cluster.yml)

| Variable | Value | Description |
|----------|-------|-------------|
| `rke2_version` | `v1.34.3+rke2r3` | RKE2 version |
| `rke2_ha_mode` | `true` | High availability mode |
| `rke2_api_ip` | `<internal-ip>` | API server endpoint (HAProxy VIP) |
| `rke2_cni` | `cilium` | Container Network Interface |
| `rke2_cluster_cidr` | `10.42.0.0/16` | Pod network CIDR |
| `rke2_service_cidr` | `10.43.0.0/16` | Service network CIDR |
| `rke2_cluster_dns` | `10.43.0.10` | Cluster DNS IP |

## Directory Structure

```
lablabs.rke2/
  defaults/main.yml      # Extensive defaults (14KB) covering all RKE2 options
  handlers/main.yml      # Service restart/start handlers
  meta/main.yml          # Galaxy metadata
  tasks/
    main.yml             # Entrypoint: server vs agent detection
    first_server.yml     # First control plane node setup
    remaining_nodes.yml  # Join additional nodes
    rke2.yml             # Core RKE2 installation
    rolling_restart.yml  # Rolling restart procedure
    keepalived.yml       # Optional keepalived setup
    kubevip.yml          # Optional kube-vip setup
    ...
  templates/
    config.yaml.j2       # RKE2 config file template
    registries.yaml.j2   # Private registry configuration
    keepalived.conf.j2   # Keepalived config
    kube-vip/            # Kube-vip manifests
    ...
  vars/main.yml          # Internal variables
  molecule/              # Molecule test scenarios
```

## Notes

- This role is excluded from Ansible-lint due to backslash regex patterns that trigger upstream bugs
- The role is excluded from yamllint via `.yamllint` configuration
- Configuration is driven by variables in `group_vars/k8s_cluster.yml` and `group_vars/masters.yml`
- RKE2 disables bundled ingress-nginx; Traefik is deployed via FluxCD instead
- Cluster token sourced from SOPS SSOT or `K8S_TOKEN` environment variable

## License

See `LICENSE` file in the role directory.
