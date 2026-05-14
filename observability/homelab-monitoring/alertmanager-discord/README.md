# alertmanager-discord (DEPRECATED)

Discord webhook adapters for AlertManager notifications. This directory is no longer deployed -- notifications now route exclusively through ntfy.

## Status

**DEPRECATED** -- Not referenced in the root `kustomization.yaml`. Kept for historical reference only. All alert routing uses ntfy receivers configured in `monitoring-release.yaml`.

## Files

| File | Description |
|------|-------------|
| `kustomization.yaml` | Kustomization referencing `deployment.yaml` and `secret.yaml` in the `monitoring` namespace. |
| `deployment.yaml` | Three Deployments (`alertmanager-discord-critical`, `-warning`, `-info`) running the `benjojo/alertmanager-discord` image on port 9094, each with a matching ClusterIP Service. Each severity tier reads its webhook URL from the `discord-webhooks` secret. Resource limits: 50m CPU / 32Mi memory per adapter. |
| `secret.yaml` | SOPS-encrypted Secret (`discord-webhooks`) containing three Discord webhook URLs: `critical-webhook`, `warning-webhook`, `info-webhook`. Encrypted with Age. |

## How It Worked

AlertManager routed alerts by severity to each adapter's webhook endpoint. The adapter converted AlertManager webhook payloads into formatted Discord embeds and posted them to the corresponding Discord channel.

## Replacement

AlertManager now sends webhooks directly to ntfy.sh using the `ntfy-critical`, `ntfy-warning`, and `ntfy-info` receivers defined in `monitoring-release.yaml`. Topic: `homelab-saltstice-critical` with varying priority levels (urgent, high, low).
