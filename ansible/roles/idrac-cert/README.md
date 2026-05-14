# iDRAC-cert

Pushes the cluster wildcard cert (`wildcard-tls` Secret in the `cert-manager`
namespace) onto the Dell iDRAC web interface via Redfish.

## Inputs

| Variable | Where from | Required |
|---|---|---|
| `idrac_url` | inventory `proxmox` group_vars (`https://<mgmt-ip>`) | yes |
| `idrac_username` | `cred-ssot-monitoring` -> `CRED_MONITORING_IDRAC_USERNAME` | yes |
| `idrac_password` | `cred-ssot-monitoring` -> `CRED_MONITORING_IDRAC_PASSWORD` | yes |
| `idrac_cert_renewal_threshold_days` | role default (30) | no |

## Behavior

The role is idempotent and safe to run on a schedule:

1. GETs the current iDRAC server cert from
 `/redfish/v1/Managers/iDRAC.Embedded.1/Certificates/SecurityCertificate.1`
 and parses `ValidNotAfter`.
2. If days remaining > `idrac_cert_renewal_threshold_days`, ends the play.
 No upload, no service restart, no diff.
3. Otherwise pulls `wildcard-tls.tls.crt` + `tls.key` from the cluster,
 concatenates them as one PEM, base64-encodes the bundle, and POSTs to
 `DelliDRACCardService.ImportSSLCertificate`.
4. Triggers `Manager.Reset` with `ResetType=GracefulRestart`, then waits
 for the iDRAC API to come back (~30-60s).
5. Re-fetches the cert metadata and prints the new expiry.

## Why i do not use the standard Redfish `ReplaceCertificate`

Dell iDRAC9 firmware predates that endpoint accepting the private key
in a single call. The Oem `ImportSSLCertificate` action is documented
across iDRAC9 firmware revisions back to 5.x and is what Dell support
references in their cert-rotation runbooks.

## Why i delegate to localhost

iDRAC is not an Ansible inventory target, there is no sshd. i delegate
the `uri` and `kubernetes.core.k8s_info` tasks to the controller and
talk to the iDRAC's HTTPS endpoint directly.

## Why `validate_certs: false` permanently

The Subject CN on the wildcard cert is `*.example.com`; the iDRAC
is contacted by IP. Hostname validation will never match. Network-layer
trust comes from the management VLAN (<mgmt-ip>/24) being isolated.
