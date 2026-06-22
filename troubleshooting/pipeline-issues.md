# GitLab CI Pipeline Troubleshooting

## Overview

This guide covers GitLab CI/CD pipeline failures in the Salty Homelab. All infrastructure
changes flow through CI pipelines, this is the first place to check when a deployment fails.

## Quick Diagnosis

```bash
# List recent pipelines for a project
glab ci list

# Get pipeline details
glab ci get --pipeline-id <ID>

# View job logs (requires interactive terminal)
glab ci view
```

## Pipeline Status Reference

| Status | Meaning | Action |
|--------|---------|--------|
| `pending` | Waiting for runner | Check runner availability |
| `running` | Actively executing | Wait or check logs |
| `failed` | One or more jobs failed | Check job logs |
| `canceled` | Manually canceled | Re-run if needed |
| `blocked` | Waiting for manual approval | Approve in GitLab UI |
| `skipped` | Rules not matched | Expected, no action |

## Common Failure: Runner System Failure

### Symptoms

```
failure_reason: runner_system_failure
```

### Causes

- CI runner pod is unhealthy or restarting
- Runner has no available capacity
- Kubernetes pod scheduling issue on runner VM

### Diagnosis

```bash
# Check runner status
glab api "runners/all" | python3 -c "
import sys, json
runners = json.load(sys.stdin)
for r in runners:
    print(r.get('id'), r.get('description'), r.get('status'))
"

# Check runner pod in Kubernetes
kubectl get pods -n gitlab-runner
kubectl describe pod -n gitlab-runner -l app=gitlab-runner

# Check runner logs
kubectl logs -n gitlab-runner -l app=gitlab-runner --tail=100
```

### Fix

```bash
# Restart the runner deployment
kubectl rollout restart deployment -n gitlab-runner gitlab-runner

# Retry the failed job via API
glab api "projects/<project-path>/jobs/<job-id>/retry" --method POST
```

## Common Failure: Markdownlint

### Symptoms

```
lint:markdown failed
```

### Causes

- Markdown file violates enabled linting rules
- Hard tabs in non-code content (MD010)
- Empty links in document (MD042)

### Diagnosis

```bash
# Run markdownlint locally (same rules as CI)
npx markdownlint-cli "**/*.md" --disable MD013 MD033 MD041

# Check specific file
npx markdownlint-cli "path/to/file.md" --disable MD013 MD033 MD041
```

### Common Fixes

| Error | Rule | Fix |
|-------|------|-----|
| Hard tab character | MD010 | Replace tabs with spaces |
| Empty link `[]()` | MD042 | Add link text or remove brackets |
| Duplicate heading | MD024 | Disabled, not checked |
| Line too long | MD013 | Disabled, not checked |

Note: The repo `.markdownlint.yaml` disables many rules that the CI template still
checks. The CI template only disables MD013, MD033, MD041 via `MARKDOWNLINT_DISABLE`.

## Common Failure: YAML Lint

### Symptoms

```
lint:yamllint failed
```

### Causes

- Trailing spaces
- Inconsistent indentation
- Missing newline at end of file
- Duplicate keys

### Diagnosis

```bash
# Run yamllint locally
pip install yamllint
yamllint -c .yamllint --no-warnings .

# Check specific file
yamllint path/to/file.yaml
```

## Common Failure: Dockerfile / Image Build

### Symptoms

```
build:docker failed
```

### Causes

- Base image pull failed (Harbor proxy issue)
- Build context too large
- Dockerfile syntax error
- Registry authentication failure

### Diagnosis

```bash
# Check Harbor proxy status
kubectl get pods -n harbor

# Test image pull manually on CI runner host
docker pull harbor.example.com/dockerhub-proxy/library/alpine:3.23

# Check job logs for specific error
glab api "projects/<project>/jobs/<id>/trace"
```

### Fix for Harbor Proxy Issues

```bash
# Check containerd mirrors configuration on worker nodes
ssh debian@<internal-ip> "cat /etc/containerd/config.toml | grep -A5 registry"

# Restart containerd if needed (do via Ansible, not manually)
# Use: ansible-playbook ansible/playbooks/restart-containerd.yml
```

## Common Failure: Ansible Lint

### Symptoms

```
lint:ansible failed
```

### Causes

- Task missing `name` field
- Using `shell` when a module exists
- Missing `become: true` for privileged tasks
- Deprecated module syntax

### Diagnosis

```bash
# Install and run ansible-lint locally
pip install ansible-lint
cd homelab-ansible
ansible-lint playbooks/

# Check specific playbook
ansible-lint playbooks/my-playbook.yml
```

## Common Failure: Terraform Validate

### Symptoms

```
terraform:validate failed
```

### Causes

- Invalid HCL syntax
- Missing required variables
- Undefined resource references
- Provider version constraint violation

### Diagnosis

```bash
cd homelab-terraform
terraform init
terraform validate

# Check formatting
terraform fmt -check -recursive
```

## Common Failure: SOPS / Secret Decryption

### Symptoms

```
ERROR: Failed to decrypt secret
sops: error decrypting file
```

### Causes

- CI runner lacks the SOPS Age key
- Age key not stored in the correct CI variable
- Wrong key for the encrypted file

### Diagnosis

```bash
# Check CI variable exists
glab api "projects/<project>/variables" | python3 -c "
import sys, json
vars = json.load(sys.stdin)
for v in vars:
    print(v.get('key'), '(protected)' if v.get('protected') else '')
"

# Verify the SOPS key fingerprint matches
cat secrets/.sops.yaml  # Check expected key recipients
```

### Fix

The SOPS Age key must be set as a CI variable `SOPS_AGE_KEY` in the project settings.
Check `Settings → CI/CD → Variables` in GitLab.

## Merge Request Pipeline vs Branch Pipeline

Pipelines run in two contexts with different rules:

| Context | Trigger | Rules Checked |
|---------|---------|---------------|
| MR pipeline | `CI_PIPELINE_SOURCE == "merge_request_event"` | Most lint jobs |
| Branch pipeline | `CI_COMMIT_BRANCH == "main"` | Deploy jobs |
| Duplicate prevention | `CI_OPEN_MERGE_REQUESTS` check | Prevents double pipelines |

If a pipeline doesn't run on an MR, check `workflow:rules` in `.gitlab-ci.yml`.

## Pipeline Won't Merge (MR Blocked)

### Symptom

```
The pipeline for this merge request has failed.
The pipeline must succeed before merging.
```

### Investigation Steps

1. Check which job failed: `glab ci get --pipeline-id <ID>`
2. Get the job ID: `glab api "projects/<project>/pipelines/<id>/jobs"`
3. View failure reason: `glab api "projects/<project>/jobs/<job-id>"`
4. If `runner_system_failure`: retry the job
5. If script failure: fix the issue and push

### Retry a Failed Job

```bash
glab api "projects/<project-path>/jobs/<job-id>/retry" --method POST
```

Note: Use URL-encoded project path, e.g., `infrastructure%2Fhomelab-docs`

## Debugging Tips

### Get Job Logs via API

The `glab ci trace` command requires an interactive terminal. Use the API directly:

```bash
# Get job ID from pipeline
glab api "projects/infrastructure%2Fhomelab-docs/pipelines/<id>/jobs" \
  | python3 -c "
import sys, json
jobs = json.load(sys.stdin)
for j in jobs:
    print(j['id'], j['name'], j['status'])
"

# Get failure reason for a job
glab api "projects/infrastructure%2Fhomelab-docs/jobs/<job-id>" \
  | python3 -c "
import sys, json
j = json.load(sys.stdin)
print('Status:', j['status'])
print('Failure:', j.get('failure_reason'))
"
```

### Test Pipeline Locally

For Ansible playbooks, test locally before pushing:

```bash
cd homelab-ansible
ansible-playbook playbook.yml --check --diff -i inventory/hosts.yml
```

For Terraform:

```bash
cd homelab-terraform
terraform plan
```

## Related Files

| File | Purpose |
|------|---------|
| `.gitlab-ci.yml` | Pipeline configuration |
| `homelab-ci-templates/lint.yml` | Shared lint job definitions |
| `homelab-ci-templates/security.yml` | Security scanning jobs |
| [troubleshooting/Flux-issues.md](flux-issues.md) | FluxCD reconciliation issues |
