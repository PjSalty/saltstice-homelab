# mktxp

MKTXP (MikroTik Prometheus Exporter) deployment for collecting metrics from all MikroTik network devices. Deployed to the `monitoring` namespace.

## Overview

MKTXP connects to MikroTik devices via the RouterOS API (port 8728) and exposes metrics in Prometheus format on port 49090. Prometheus scrapes these metrics via both a ServiceMonitor and a static scrape config in the HelmRelease.

## Monitored Devices

| Device | IP | Metrics Collected |
|--------|-----|-------------------|
| RB4011 (Core Router) | <mgmt-ip> | Interfaces, firewall, DHCP, connections, connection stats, routes, netwatch, public IP, queue |
| CRS317 (10G Switch) | <mgmt-ip> | Interfaces, monitor, installed packages, users |
| CRS328 (PoE Switch) | <mgmt-ip> | Interfaces, PoE, monitor, installed packages, users |

## Directory Structure

```
mktxp/
  base/           Kustomization with deployment, secret, and service monitor
```

See `base/README.md` for file details.
