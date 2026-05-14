# mktxp/base

Base Kustomization for the MKTXP MikroTik Prometheus exporter.

## Files

| File | Description |
|------|-------------|
| `kustomization.yaml` | Kustomization listing all resources. Applies labels `app.kubernetes.io/name: mktxp` and `app.kubernetes.io/component: exporter` to all resources. |
| `deployment.yaml` | Contains three resources: a ConfigMap (`mktxp-config`), a Deployment (`mktxp`), and a Service (`mktxp`). |
| `secret.yaml` | SOPS-encrypted Secret (`mktxp-credentials`) containing `username` and `password` for the MikroTik `prometheus` API user. Encrypted with Age. |
| `servicemonitor.yaml` | Prometheus Operator ServiceMonitor for auto-discovery. Scrapes the `metrics` port at `/metrics` every 30s with a 25s timeout. |

## Deployment Details

The Deployment uses an init container pattern:

1. **Init container** (`config-init`): Copies config templates from the ConfigMap to an emptyDir volume, then uses `sed` to replace `__PASSWORD_PLACEHOLDER__` with the actual password from the `mktxp-credentials` secret.
2. **Main container** (`mktxp`): Runs the MKTXP exporter using the prepared config files. Exposes port 49090 for metrics.

Resource limits: 500m CPU / 512Mi memory for the main container.

## ConfigMap Structure

The ConfigMap contains two files:

- **`mktxp.conf`**: Per-device configuration with three sections (`[RB4011]`, `[CRS317]`, `[CRS328]`). Each section defines the device hostname, port (8728), and which metric collectors to enable. The RB4011 has the most collectors enabled (DHCP, firewall, connections, routes, etc.) while the switches primarily collect interface and PoE metrics.
- **`_mktxp.conf`**: Global exporter settings including the listen port (49090), socket timeout (2s), bandwidth test interval (600s), max scrape duration (10s per device, 30s total), and parallel fetch disabled.

## Key Configuration Options

| Option | Value | Description |
|--------|-------|-------------|
| `port` | 49090 | Prometheus metrics endpoint port |
| `socket_timeout` | 2s | Timeout for RouterOS API connections |
| `max_scrape_duration` | 10s | Per-device scrape timeout |
| `total_max_scrape_duration` | 30s | Total scrape timeout across all devices |
| `bandwidth_test_interval` | 600s | How often to run bandwidth tests |
| `compact_default_conf_values` | True | Required for newer MKTXP versions |
