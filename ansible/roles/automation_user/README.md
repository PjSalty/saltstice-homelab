# automation_user

Creates a dedicated automation user account for CI/CD pipeline access. This system account has NOPASSWD sudo for Ansible become operations, with security boundaries enforced via SSH key-only auth and a dedicated account.

## Tasks (tasks/main.yml)

1. Create the `automation` system user with home directory
2. Create `.ssh` directory with 0700 permissions
3. Deploy the authorized SSH public key (exclusive mode -- removes other keys)
4. Deploy sudoers file at `/etc/sudoers.d/10-automation` granting NOPASSWD ALL

## Variables (defaults/main.yml)

| Variable | Default | Description |
|----------|---------|-------------|
| `automation_user_name` | `automation` | Account username |
| `automation_user_comment` | `Ansible CI/CD automation` | User description |
| `automation_user_shell` | `/bin/bash` | Login shell |
| `automation_user_home` | `/home/automation` | Home directory |
| `automation_user_ssh_pubkey` | (ed25519 key) | SSH public key matching the CI/CD private key |

## Security Model

- SSH key-only authentication (no password)
- Dedicated system account (not shared with interactive users)
- The `use_pty` sudo restriction is disabled for this user to allow non-interactive Ansible execution
- The private key resides in the K8s secret `automation-ssh-key` and is mounted into CI runner containers

## Tags

`automation_user`, `setup`, `ssh`, `sudo`

## Usage

Run once to bootstrap the automation user on all hosts:

```bash
ansible-playbook playbooks/operations/deploy-automation-user.yml
```

After this, the CI/CD pipeline connects as the `automation` user for all subsequent deploys.
