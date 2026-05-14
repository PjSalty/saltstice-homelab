# Runbook: rotate a secret managed by ESO

Generic procedure for rotating a credential whose value lives in a
SOPS-encrypted YAML in the secrets repo and is propagated to apps
via ExternalSecrets Operator.

## Concept

```
secrets repo (SOPS)  →  Flux decrypts  →  shared Secret  →  ESO  →  app namespaces
```

Rotation = update the value in the secrets repo, push, wait for Flux,
then either wait for ESO refresh or force a refresh + restart the
consumer pods.

## Steps

### 1. Generate the new value

```bash
# example: a 32-byte hex token
openssl rand -hex 32
```

For OIDC client secrets, generate inside Authentik / your IdP and
copy the new value out before saving.

### 2. Update the secrets repo

```bash
cd ~/GIT/secrets

# Decrypt, edit, re-encrypt in one step
sops kubernetes/shared/oidc-client-secrets.yaml
# (your editor opens with the decrypted YAML; edit the value, save, exit)

git add kubernetes/shared/oidc-client-secrets.yaml
git commit -m "rotate: <SECRET-NAME>"
git push
```

### 3. Force Flux to reconcile the secrets source

```bash
flux reconcile source git secrets
flux reconcile kustomization secrets
```

The `shared/oidc-client-secrets` Secret in the cluster now has the
new value.

### 4. Force ESO to refresh

By default ESO refreshes every `refreshInterval` (often 1h). Force
it now:

```bash
# annotate the ExternalSecret to trigger immediate refresh
kubectl annotate externalsecret -n <APP-NS> <SECRET-NAME> \
  force-sync=$(date +%s) --overwrite
```

The downstream `Secret` in the app namespace updates within seconds.

### 5. Restart consumers

Most apps don't reload their secret values without a restart.

```bash
# rolling restart picks up the new value at next pod start
kubectl rollout restart -n <APP-NS> deployment/<DEPLOYMENT>
# or for StatefulSets
kubectl rollout restart -n <APP-NS> statefulset/<NAME>
```

For apps that watch their config file (less common), check whether
they handle SIGHUP and use that instead.

### 6. Verify

```bash
# new value present in the namespace Secret
kubectl get secret -n <APP-NS> <SECRET-NAME> -o jsonpath='{.metadata.resourceVersion}'

# app-side: log in / re-issue token / hit the endpoint that uses the
# secret. Failure here means the consumer didn't restart cleanly or
# the IdP wasn't actually updated.
```

### 7. Update the IdP / external system

For OIDC / API keys / cloud credentials: the rotation isn't done
until the issuing system also has the new value. Order matters per
secret type:

- **OIDC client secret**: update IdP first OR set both old + new
 valid simultaneously (most IdPs support this), then rotate the
 client side.
- **Database password**: change in the database, then update the
 secret. Connection pool will fail mid-rotation; coordinate with a
 brief restart.
- **API token**: issue new token first, store both, swap, revoke
 old. Never swap before issuing.

## What this does not cover

- The bootstrap Age key for SOPS itself. That rotation has its own
 procedure (add new recipient, `sops updatekeys` on every file,
 remove old recipient, `sops updatekeys` again).
- Initial credential generation. This is rotation, not creation.

## Related

- [How-to: bootstrap Flux with SOPS-Age](../how-to/bootstrap-flux-with-sops-age.md)
- [ADR: SOPS-Age + ESO](../docs/adrs/sops-age-with-eso.md)
