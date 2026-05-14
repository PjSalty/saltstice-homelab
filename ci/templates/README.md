# CI/CD Templates

Reusable GitLab CI/CD templates and shared configs for the Salty Homelab infrastructure.

## Shared Configurations

### Pre-commit Hooks

Copy `.pre-commit-config.yaml` to your repo root:

```bash
curl -sO https://gitlab.example.com/infrastructure/homelab-ci-templates/-/raw/main/.pre-commit-config.yaml
pre-commit install
```

Includes hooks for:
- YAML linting
- Shell script checking (shellcheck)
- Terraform formatting/validation
- Python formatting (black, flake8)
- Ansible linting
- Kubernetes manifest validation
- Secret detection (gitleaks)
- Markdown linting

### YAML Lint

Copy `.yamllint` to your repo root for consistent YAML linting.

## CI/CD Templates Usage

Include templates in your `.gitlab-ci.yml`:

```yaml
include:
  - project: 'infrastructure/homelab-ci-templates'
    file: '/terraform.yml'
  - project: 'infrastructure/homelab-ci-templates'
    file: '/ansible.yml'
  - project: 'infrastructure/homelab-ci-templates'
    file: '/kubernetes.yml'
```

Then extend the jobs you need:

```yaml
terraform:validate:
  extends: .terraform:validate

terraform:plan:
  extends: .terraform:plan

terraform:apply:
  extends: .terraform:apply
  needs:
    - terraform:plan
```

## Available Templates

### Terraform (`terraform.yml`)

| Job | Stage | Description |
|-----|-------|-------------|
| `.terraform:validate` | validate | Format check, syntax validation |
| `.terraform:plan` | plan | Generate execution plan |
| `.terraform:apply` | deploy | Apply changes (main branch only) |

### Ansible (`ansible.yml`)

| Job | Stage | Description |
|-----|-------|-------------|
| `.ansible:lint` | validate | Syntax check, Ansible-lint |
| `.ansible:check` | plan | Dry-run (--check --diff) |
| `.ansible:deploy` | deploy | Apply playbooks |

### Kubernetes (`kubernetes.yml`)

| Job | Stage | Description |
|-----|-------|-------------|
| `.kubernetes:validate` | validate | YAML lint |
| `.kubernetes:diff` | plan | kubectl diff |
| `.flux:reconcile` | deploy | Flux reconciliation |
| `.kubernetes:verify` | verify | Cluster health check |

### Docker (`docker.yml`)

| Job | Stage | Description |
|-----|-------|-------------|
| `.docker:build` | build | Build and push image |
| `.docker:scan` | test | Trivy security scan |
| `.docker:push-harbor` | deploy | Push to Harbor registry |

## Required CI/CD Variables

| Variable | Description | Required For |
|----------|-------------|--------------|
| `KUBE_CONFIG` | Base64-encoded kubeconfig | Kubernetes, Flux |
| `SSH_PRIVATE_KEY` | SSH key for Ansible | Ansible |
| `SOPS_AGE_KEY` | Base64-encoded Age key | SOPS decryption |
| `HARBOR_USER` | Harbor registry username | Docker push |
| `HARBOR_PASSWORD` | Harbor registry password | Docker push |
| `GITLAB_TOKEN` | GitLab API token | Git operations |

## Customization

Override variables in your job definition:

```yaml
my-terraform:
  extends: .terraform:apply
  variables:
    TF_DIR: "terraform/modules/my-module"
```

## Syncing to Other Repos

To sync shared configs to other repos, run from each repo:

```bash
# Pre-commit config
curl -sO https://gitlab.example.com/infrastructure/homelab-ci-templates/-/raw/main/.pre-commit-config.yaml

# YAML lint config
curl -sO https://gitlab.example.com/infrastructure/homelab-ci-templates/-/raw/main/.yamllint
```
