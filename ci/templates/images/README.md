# Container Images

Custom Docker images built and pushed to Harbor for use in GitLab CI/CD pipelines.

## Images

### Ansible-runner

A Python-based CI runner image pre-configured with Ansible, SOPS, and SSH tooling.

| Detail | Value |
|--------|-------|
| Base | `python:3.12-slim` (Debian) |
| Registry | `harbor.example.com/homelab/ansible-runner` |
| User | `gitlab-runner` (UID 1000) |
| Purpose | Run Ansible playbooks in GitLab CI deploy jobs |

Includes:

- Ansible and Ansible-lint (versions pinned in `requirements.txt`)
- SOPS v3.11.0 for secret decryption
- `community.sops` and `community.general` Ansible Galaxy collections
- OpenSSH client, git, curl, CA certificates

The image has its own `.gitlab-ci.yml` for automated builds via the `container-build.yml` template.

**Files:**

| File | Description |
|------|-------------|
| `Dockerfile` | Multi-stage build definition |
| `requirements.txt` | Pinned Python dependencies (Ansible, pynetbox, etc.) |
| `.gitlab-ci.yml` | CI pipeline for building and pushing the image |

### media-drop-watcher

A lightweight Alpine-based image for the media drop watcher CronJob that organizes media files dropped into NFS shares.

| Detail | Value |
|--------|-------|
| Base | `python:3.12-alpine` |
| Registry | `harbor.example.com/homelab/media-drop-watcher` |
| User | UID 568 (matches K8s securityContext) |
| Purpose | Pre-install ffprobe and GuessIt to eliminate init containers |

Includes:

- ffmpeg (provides ffprobe for video resolution detection)
- GuessIt (Python library for media filename parsing, pinned in `requirements.txt`)

Python scripts are mounted as ConfigMap volumes at runtime, not baked into the image.

**Files:**

| File | Description |
|------|-------------|
| `Dockerfile` | Image build definition |
| `requirements.txt` | Pinned Python dependencies (guessit) |
| `.dockerignore` | Build context exclusions |

## Build Process

All images use the `container-build.yml` CI template with the standard pipeline flow:

```
build (sha tag) --> scan (Trivy gate) --> promote (sha --> release tag)
```

Images are pushed to Harbor at `harbor.example.com/homelab/`.

## Adding a New Image

1. Create a new directory under `images/` with the image name
2. Add a `Dockerfile`, `requirements.txt` (if applicable), and `.gitlab-ci.yml`
3. Include the `container-build.yml` template in the CI config
4. Pin all base images by digest per ADR-0001
