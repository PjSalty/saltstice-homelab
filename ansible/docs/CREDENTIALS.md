# Credentials Management

## Architecture

All credentials flow through a unified SSOT (Single Source of Truth) file encrypted with SOPS + Age.

```
credentials.sops.yaml (SSOT)
        |
        ├── Ansible rotation playbook
        │   ├── Generates new credentials
        │   ├── Applies to services (API calls)
        │   ├── Validates all endpoints
        │   └── Syncs to Vaultwarden on 100% pass
        │
        └── K8s Secrets (infrastructure/secrets repo)
            └── Flux reconciles to cluster
```

## Usage

```bash
# Check credential status
ansible-playbook playbooks/operations/rotate-credentials.yml -e cred_mode=status

# Dry run (show what would change)
ansible-playbook playbooks/operations/rotate-credentials.yml -e cred_mode=dry-run

# Rotate all credentials
ansible-playbook playbooks/operations/rotate-credentials.yml -e cred_mode=rotate

# Rotate specific category
ansible-playbook playbooks/operations/rotate-credentials.yml -e cred_mode=rotate -e cred_categories=kubernetes
```

## Safety

- **Mandatory dry-run**: Rotation mode runs dry-run first automatically
- **Per-service lockfiles**: Prevents concurrent rotation of the same service
- **Backup before rotation**: SSOT is backed up before any changes
- **Rollback on failure**: If validation fails, previous credentials are restored
- **One service at a time**: Services are rotated sequentially, not in parallel

## SOPS Encryption

```bash
# Decrypt SSOT
sops -d secrets/credentials.sops.yaml

# Edit SSOT
sops secrets/credentials.sops.yaml

# Encrypt new file
sops -e --age <AGE_PUBLIC_KEY> newfile.yaml > newfile.sops.yaml
```

Keys are ALWAYS plaintext. Only VALUES are encrypted.
