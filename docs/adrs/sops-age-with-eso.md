# ADR: SOPS-Age + External Secrets Operator

**Status:** Accepted

## Context

Need encrypted secrets in Git. Standard options: SealedSecrets, Vault,
SOPS, Bitnami Sealed-Secrets, ExternalSecrets pulling from a cloud
KMS, etc. Plus a decision on what tool decrypts them inside the
cluster.

## Decision

SOPS encrypted with Age keys for at-rest encryption in the secrets
repo. External Secrets Operator (ESO) propagates the decrypted values
into per-namespace `Secret` resources via SecretStore label selectors.

## Reasoning

SOPS over SealedSecrets. SOPS encrypts only values, leaves keys
plaintext, and the encrypted file is human-readable diff-friendly.
SealedSecrets are opaque, you can't see what's changing in a
diff except by inspecting the encrypted blob.

Age over GPG. Age keys are short, single-purpose, no web of trust to
manage. GPG works but the operational overhead (key servers, expiry,
subkeys) doesn't pay for itself in a single-cluster homelab.

ESO over decrypting directly into Secrets via Flux. Flux's SOPS
decryption produces one Secret per encrypted file in the source repo.
That couples manifest layout to secret layout. ESO decouples them:
secrets repo just defines the values; per-namespace SecretStore +
ExternalSecret declares "i want these keys, named like this, into a
Secret in my namespace."

Bonus: ESO's `creationPolicy` controls whether ESO owns the secret
fully or merges into an existing one (gotcha: `Merge` requires the
target Secret to already exist).

## What i gave up

Vault. Real Vault has dynamic secrets, lease management, audit
trails. SOPS is static encrypted-at-rest. For a one-cluster homelab,
the operational cost of running Vault outweighs the gains. Re-evaluate
if dynamic credentials become a need.

KMS-backed decryption. Cloud KMS would give you HSM-backed keys.
Age does not. The Age key file in the cluster is the trust root.

## Architecture

```
[ secrets repo (gitlab) ]
        │
        │  contains SOPS-encrypted YAML, Age-protected
        ▼
[ Flux GitRepository: secrets ]
        │
        │  Kustomization "secrets" with decryption.provider=sops,
        │  secretRef: sops-age (mounts the Age private key)
        ▼
[ K8s Secret (decrypted) in flux-system or shared ns ]
        │
        ▼
[ External Secrets Operator ]
        │
        │  per-namespace SecretStore with label selector
        ▼
[ ExternalSecret in app namespace ]
        │
        ▼
[ K8s Secret in app namespace, scoped to that app only ]
```

Per-namespace SecretStore label selector means apps only ever see the
secrets explicitly granted to them. No accidental cross-namespace
leakage even though the source-of-truth secret lives elsewhere.

## Pre-commit hooks for safety

Every repo runs gitleaks + a personal-PII scanner before commit. The
scanner reverse-checks: scan staged content for the LITERAL VALUES of
any env vars in the maintainer's `.pii-patterns`, not just for
suspicious-looking strings. Catches the "i pasted my real value into a
README to test something and forgot" case that gitleaks would miss.

## When i would reconsider

- Multi-cluster fleet → Vault makes sense at that scale.
- Compliance requirement for HSM-backed keys → KMS-backed decryption.
- Cluster grows past where one Age key file is acceptable trust root
 → Vault with PKI-backed identity.
