# Ansible Runner for GitLab CI
# Runs as UID 1000 with proper user entry for SSH
# Version: 2026-02-04 - BuildKit migration via Harbor proxy
# Pull directly from Docker Hub - BuildKit handles auth for rate limits
# Digest pinned per ADR-0001 — Renovate auto-updates digest
FROM python:3.12-slim@sha256:d6b046b27fe57002af7655dd6aa4ce3bc8a42a4621d7a5b4056a417e0d9952f5

# Create gitlab-runner user with UID 1000
RUN useradd -u 1000 -m -s /bin/bash gitlab-runner && \
    mkdir -p /home/gitlab-runner/.ssh && \
    chown -R gitlab-runner:gitlab-runner /home/gitlab-runner

# Install system dependencies
# Use HTTPS for apt repos — DinD in K8s can't reach deb.debian.org on HTTP/80
RUN sed -i 's|http://|https://|g' /etc/apt/sources.list.d/* && \
    apt-get update && apt-get install -y --no-install-recommends \
    openssh-client \
    git \
    curl \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Install Ansible and dependencies from requirements.txt
# Versions are pinned in requirements.txt for Renovate to track
COPY requirements.txt /tmp/requirements.txt
RUN pip install --no-cache-dir -r /tmp/requirements.txt && rm /tmp/requirements.txt

# Install SOPS - Version pinned per ADR-0001 SSOT - Researched: 2026-02-02
RUN curl -sLO "https://github.com/getsops/sops/releases/download/v3.11.0/sops-v3.11.0.linux.amd64" && \
    chmod +x sops-v3.11.0.linux.amd64 && \
    mv sops-v3.11.0.linux.amd64 /usr/local/bin/sops

# Install Ansible collections
RUN ansible-galaxy collection install community.sops community.general

# Set working directory
WORKDIR /builds

# Run as gitlab-runner user
USER gitlab-runner

# Default command
CMD ["ansible", "--version"]
