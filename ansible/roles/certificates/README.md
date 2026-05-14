# certificates

Deploys TLS certificates from cert-manager to VM-based services. Certificates are extracted from the `wildcard-tls` Kubernetes secret in the `cert-manager` namespace and placed at service-specific paths on each VM.

## Tasks (tasks/main.yml)

1. Make sure SSL directories exist (`/etc/ssl/certs`, `/etc/ssl/private`)
2. Deploy TLS certificate file to service-specific path
3. Deploy TLS private key to service-specific path (mode 0600)

Certificate and key content must be provided via `cert_content` and `cert_key_content` variables (typically injected by the CI deploy-certificates job).

## Variables (defaults/main.yml)

| Variable | Default | Description |
|----------|---------|-------------|
| `certificates_source_secret` | `wildcard-tls` | K8s secret name containing the certificate |
| `certificates_source_namespace` | `cert-manager` | K8s namespace of the certificate secret |
| `certificates_deploy_paths` | (dict) | Per-service cert and key file paths |

### Deploy Paths

| Service | Certificate Path | Key Path |
|---------|-----------------|----------|
| `gitlab` | `/data/gitlab/config/ssl/gitlab.example.com.crt` | `.key` |
| `harbor` | `/data/harbor/secret/cert/server.crt` | `server.key` |
| `proxmox` | `/etc/pve/local/pveproxy-ssl.pem` | `pveproxy-ssl.key` |
| `netbox` | `/etc/ssl/certs/netbox.example.com.crt` | `.key` |
| `adguard` | `/etc/ssl/certs/adguard.example.com.crt` | `.key` |
| `truenas` | `/etc/ssl/certs/truenas.example.com.crt` | `.key` |

### Per-Host Variables

- `cert_name` -- Set in inventory; maps to a key in `certificates_deploy_paths`
- `cert_content` -- Certificate PEM content (injected at runtime)
- `cert_key_content` -- Private key PEM content (injected at runtime)

## Handlers

- `Restart pveproxy` -- Restarts Proxmox pveproxy (only for cert_name == 'Proxmox')

## Tags

`certificates`
