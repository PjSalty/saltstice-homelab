# collections/

Ansible Galaxy collection dependencies required by this project.

## Files

| File | Purpose |
|------|---------|
| `requirements.yml` | Collection dependencies with minimum version constraints |

## Required Collections

| Collection | Minimum Version | Used By |
|------------|----------------|---------|
| `ansible.posix` | 1.6.0 | sysctl, authorized_key, modprobe tasks |
| `community.general` | <internal-net> | timezone, locale_gen, UFW, modprobe tasks |
| `community.docker` | 4.0.0 | docker_compose_v2, docker_container_info tasks |
| `community.crypto` | 2.22.0 | Certificate operations |
| `community.sops` | 2.2.0 | SOPS credential decryption |

## Installation

```bash
ansible-galaxy collection install -r collections/requirements.yml
```

Collections are also installed automatically by the CI pipeline's Ansible-runner Docker image.
