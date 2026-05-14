# How-to: bootstrap Flux with SOPS-Age decryption

End-to-end. Assumes a working K8s cluster, a Git remote, and the
`flux` CLI installed.

## 1. Generate an Age key

```bash
age-keygen -o age.key
# age.key has the form:
#   # public key: age1...
#   AGE-SECRET-KEY-1...
```

Two halves: a public key (use this to encrypt) and a private key
(only the cluster decrypts with this).

Treat the private key like an SSH key. Don't commit it. Keep one
canonical copy in a password manager and one ephemeral copy you
delete after seeding the cluster.

## 2. Create the cluster-side secret

The Age private key needs to live as a Kubernetes Secret that Flux
reads at decrypt time.

```bash
kubectl create namespace flux-system
kubectl create secret generic sops-age \
  --namespace flux-system \
  --from-file=age.agekey=age.key
```

Then delete the local `age.key` once you've confirmed the Secret is
in place (and saved the private key in your password manager).

## 3. Tell Kustomize what to encrypt

Top-level `.sops.yaml` in the secrets repo controls which keys get
encrypted in which files:

```yaml
creation_rules:
  - path_regex: kubernetes/.*\.yaml$
    encrypted_regex: ^(data|stringData)$
    age: age1xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
```

Only `data` and `stringData` get encrypted. Keys (resource names,
namespaces, labels) stay plaintext so the diff is human-readable.

## 4. Encrypt a secret

```bash
sops --encrypt --in-place kubernetes/auth/oidc-client-secret.yaml
```

The file becomes `ENC[AES256_GCM,...]` for the values; everything else
remains readable.

## 5. Bootstrap Flux

```bash
export GITLAB_TOKEN=...
flux bootstrap gitlab \
  --owner=infrastructure \
  --repository=homelab-kubernetes \
  --branch=main \
  --path=clusters/homelab \
  --personal=false
```

Flux installs its controllers and creates a GitRepository pointing at
the bootstrapped repo.

## 6. Wire SOPS decryption to a Kustomization

```yaml
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: secrets
  namespace: flux-system
spec:
  interval: 5m
  path: ./kubernetes
  prune: true
  sourceRef:
    kind: GitRepository
    name: secrets
  decryption:
    provider: sops
    secretRef:
      name: sops-age
```

`secretRef` points at the `sops-age` Secret created in step 2. Flux
mounts it as `/etc/sops-age/age.agekey` in the kustomize-controller
pod and uses it to decrypt every encrypted file under `path`.

## 7. (Recommended) Multi-source: secrets in a separate repo

A second GitRepository pointed at a dedicated secrets repo, with
every app Kustomization `dependsOn: [secrets]`. Rotation in the
secrets repo doesn't trigger app reconciliation that doesn't need to
happen. See [ADR `flux-multi-source`](../docs/adrs/flux-multi-source.md).

## 8. Add ESO for per-namespace secret propagation

Flux decrypts secrets into one namespace (`flux-system` or `shared`).
ExternalSecrets Operator propagates them out to per-namespace
`Secret` resources.

```yaml
apiVersion: external-secrets.io/v1beta1
kind: SecretStore
metadata:
  name: cluster-secrets
  namespace: my-app
spec:
  provider:
    kubernetes:
      remoteNamespace: shared
      auth:
        serviceAccount:
          name: external-secrets
      server:
        caProvider:
          type: ConfigMap
          name: kube-root-ca.crt
          key: ca.crt
---
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: oidc-client-secret
  namespace: my-app
spec:
  refreshInterval: 1h
  secretStoreRef:
    kind: SecretStore
    name: cluster-secrets
  target:
    name: oidc-client-secret
    creationPolicy: Owner
  data:
    - secretKey: clientSecret
      remoteRef:
        key: oidc-client-secrets
        property: my-app
```

`creationPolicy: Owner` lets ESO create the target Secret. `Merge`
requires it to already exist. The `Merge` mode silently fails if you
forget to pre-create, easy hour to lose.

## 9. Pre-commit hook to keep plaintext secrets out

Every repo (apps and secrets) runs gitleaks + a custom PII scanner
on staged changes. Loaded from a gitignored `.pii-patterns` file
that lists maintainer-specific tokens (real name, personal email,
WAN IP) the scanner blocks on. No `git push` should ever surface a
plaintext secret because it never makes it past `git commit`.

## 10. Rotate

Generate a new Age public key, add it to the `.sops.yaml` recipients
list, run `sops updatekeys` on every encrypted file, commit, push.
Old recipients stay valid until you remove them from the recipient
list and re-`updatekeys`. Plan the rotation in two passes: add new,
verify decryption works, remove old.
