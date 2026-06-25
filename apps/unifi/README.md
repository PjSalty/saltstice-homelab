# UniFi Network Controller

UniFi Network Controller for managing WiFi access points. Includes a fully automated sidecar container that handles bootstrap, WiFi network creation, AP group assignment, and continuous device adoption monitoring.

## FQDN

`https://unifi.example.com`

## Namespace

`unifi`

## Directory Structure

```
base/
  kustomization.yaml                        - Kustomize manifest listing all resources
  deployments/
    unifi-deployment.yaml                   - Namespace, Deployment (controller + automation sidecar), LoadBalancer Service
  ingress/
    ingress.yaml                            - Traefik IngressRoute with Authentik forward-auth and ServersTransport
  storage/
    storage.yaml                            - PVs/PVCs for config (NFS) and DB (iSCSI)
  secrets/
    unifi-credentials.yaml                  - SOPS-encrypted controller and WiFi passwords
    netbox-token.yaml                       - SOPS-encrypted NetBox API token for AP inventory
  configmaps/
    ap-inventory.yaml                       - DEPRECATED: Static AP inventory (use NetBox instead)
    wifi-setup-script.yaml                  - WiFi setup script (used by legacy jobs)
  jobs/
    init-storage-job.yaml                   - Creates NFS directories with correct ownership
    unifi-bootstrap-job.yaml                - Legacy bootstrap job (replaced by sidecar)
    wifi-setup-job.yaml                     - Legacy WiFi setup job (replaced by sidecar)
  autoscaling/
    kustomization.yaml                      - Lists VPA resource
    vpa.yaml                                - VPA for both unifi and automation containers
```

## Key Configuration

### Deployment

The Deployment runs two containers sharing the same pod network:

**UniFi (main controller)**:
- **Image**: `${IMAGE_UNIFI_CONTROLLER}` (v9.1.120)
- **Strategy**: Recreate (required for single-instance with PVC)
- **Ports**: 8443 (HTTPS UI), 8080 (device communication), 3478/UDP (STUN), 10001/UDP (AP discovery), 6789 (speedtest)
- **Probes**: HTTPS GET `/status` on port 8443

**automation (sidecar)**:
- **Image**: `${IMAGE_UNIFI_MONGODB}` (MongoDB image with mongo CLI)
- **Purpose**: Bootstrap admin user, create WiFi networks, assign AP groups, monitor/adopt devices
- **AP inventory**: Fetched from NetBox VM API (source of truth)
- **Marker file**: `/unifi/.automation_complete` prevents re-running initial setup on restarts
- **Monitor loop**: Checks every 5 minutes for pending device adoption and firmware upgrades

**cert-injector (init container)**:
- **Image**: `${IMAGE_UNIFI_ECLIPSE_TEMURIN}` (Java JDK for keytool)
- **Purpose**: Converts wildcard TLS cert to Java keystore format for UniFi

### WiFi Networks

| SSID | VLAN | Security | AP Group | Purpose |
|------|------|----------|----------|---------|
| homelab-wifi | 70 (Trusted) | WPA2 | Local APs | Primary home network |
| IoT Network | 80 (IoT) | WPA2 | Local APs | IoT devices |
| Guest Network | 100 (Guest) | WPA2 | Local APs | Guest access |
| homelab-secure | 88 (homelab-secure) | WPA3 + 6GHz | Remote AP | Remote-only (6GHz capable) |

### AP Groups

Fetched from NetBox at startup:
- **Local APs**: ap-1 + ap-2
- **Remote AP**: remote-ap (6GHz capable)

### LoadBalancer Service

The UniFi Service uses MetalLB LoadBalancer (`${UNIFI_LB_IP}`) to expose all ports directly, which is required for AP device communication, STUN, and discovery protocols that cannot be proxied.

### Ingress

Traefik IngressRoute with:
- Authentik forward-auth (SSO for web UI)
- Security headers middleware
- `insecureSkipVerify` via ServersTransport (UniFi uses self-signed cert internally)

## Storage

| PVC | Size | StorageClass | Purpose |
|-----|------|--------------|---------|
| `unifi-config` | 5Gi | NFS (static) | Controller configuration and automation marker |
| `unifi-db` | 10Gi | `truenas-iscsi` | MongoDB data (block storage required for database) |

## Secrets

| Secret Name | Contents |
|-------------|----------|
| `unifi-credentials` | UNIFI_USER, UNIFI_PASS, NACHO_WIFI_PASS, IOT_WIFI_PASS, GUEST_WIFI_PASS, SECURE_WIFI_PASS |
| `netbox-token` | NetBox API token and URL for AP inventory |
| `wildcard-tls` | TLS cert injected into Java keystore |

## Autoscaling

- **UniFi VPA**: Auto mode (100m-2 CPU, 512Mi-2Gi memory)
- **Automation sidecar VPA**: Auto mode (10m-100m CPU, 32Mi-256Mi memory)

## Dependencies

- NetBox VM at <internal-ip> (AP inventory source of truth)
- MetalLB (LoadBalancer IP assignment)
- Authentik (SSO forward-auth for web UI)
- truenas-csi (iSCSI storage for MongoDB, provisioner csi.truenas.io)
- TrueNAS NFS (config storage)
- Wildcard TLS certificate (`wildcard-tls`)
