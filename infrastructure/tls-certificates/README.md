# TLS Certificates

SOPS-encrypted Kubernetes Secret containing the wildcard TLS certificate and private key for `*.example.com`. This is a pre-provisioned copy of the wildcard certificate that can be used as a fallback or bootstrap mechanism.

## Files

| File | Resources | Purpose |
|------|-----------|---------|
| `wildcard-tls.yaml` | Secret `wildcard-tls` (SOPS-encrypted) | Wildcard TLS certificate for `*.example.com` |

## Encryption

The Secret is encrypted with SOPS using Age encryption. The `encrypted_regex` pattern targets `data`, `stringData`, `password`, `token`, `key`, `secret`, `certificate`, and related fields. Keys remain plaintext; only values are encrypted.

FluxCD decrypts the Secret at reconciliation time using the `sops-age` Secret in the `flux-system` namespace.

## Certificate Lifecycle

The primary certificate lifecycle is managed by cert-manager:

1. **cert-manager** issues a wildcard Certificate (`*.example.com` + `*.example.com`) from Let's Encrypt via DNS-01 (acme-DNS)
2. The Certificate resource is defined in `infrastructure/configs/cert-manager/wildcard-certificate.yaml`
3. **Kyverno** policy `sync-wildcard-tls` (in `policies/kyverno/`) replicates the cert-manager-managed Secret to all namespaces that need it

This directory provides a SOPS-encrypted backup of that certificate data.
