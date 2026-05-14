# Media Drop Watcher - Custom Container Image
# Pre-installs ffprobe and GuessIt to eliminate the init container.
# File moves use NFS read-write mounts (no SSH needed).
# Python scripts stay as ConfigMap mounts (change more frequently than deps).
#
# Build: docker build -t harbor.example.com/homelab/media-drop-watcher:v1.0.0 .
# Digest pinned per ADR-0001 — Renovate auto-updates digest
FROM python:3.12-alpine@sha256:7747d47f92cfca63a6e2b50275e23dba8407c30d8ae929a88ddd49a5d3f2d331

# Apply security updates (CVE-2026-22184: zlib buffer overflow)
RUN apk upgrade --no-cache

# System dependencies for video resolution probing
RUN apk add --no-cache ffmpeg

# Python dependencies (pinned versions for Renovate tracking)
COPY requirements.txt /tmp/requirements.txt
RUN pip install --no-cache-dir -r /tmp/requirements.txt && \
    rm /tmp/requirements.txt

# Non-root user matching existing K8s securityContext UID
RUN adduser -D -u 568 -g 568 -h /home/media-mover -s /bin/sh media-mover

USER 568
WORKDIR /home/media-mover
