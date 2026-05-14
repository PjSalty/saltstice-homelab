# homelab-tooling: shared base image for K8s CronJobs/Jobs that talk to remote
# services. Replaces the runtime `apk add` / `pip install` patterns scattered
# across cloudflare-dns-sync, netbox-dns-sync, sso-complete-setup, vm-cert-sync,
# etc. — those patterns required root and broke under Kyverno's
# require-run-as-non-root policy.
#
# Bundles: python3, requests, kubectl, openssh-client, openssl, curl, ca-certs.
# Runs as UID 65534 (nobody) with /home/tooling as a writable HOME.
#
# Usage in K8s manifests:
#   image: ${IMAGE_HOMELAB_TOOLING}
#   securityContext: { runAsNonRoot: true, runAsUser: 65534 }
#
# Versions are pinned with @sha256 per ADR-0001; Renovate auto-updates digests.
FROM harbor.example.com/dockerhub-proxy/library/python:3.14-alpine@sha256:dd4d2bd5b53d9b25a51da13addf2be586beebd5387e289e798e4083d94ca837a

LABEL org.opencontainers.image.title="homelab-tooling" \
      org.opencontainers.image.description="Non-root base image for K8s Jobs/CronJobs that talk to remote services. Bundles python3+requests, kubectl, openssh-client, openssl, curl. Replaces runtime apk-add/pip-install patterns." \
      org.opencontainers.image.source="https://gitlab.example.com/infrastructure/homelab-ci-templates" \
      org.opencontainers.image.vendor="example.com" \
      org.opencontainers.image.licenses="MIT"

# kubectl version is bumped in lockstep with TOOLS_KUBECTL_VERSION in the
# image-versions SSOT (homelab-kubernetes/infrastructure/configs/ssot).
ARG KUBECTL_VERSION=1.35.4

RUN apk add --no-cache \
        openssh-client \
        openssl \
        curl \
        ca-certificates \
        bash

# kubectl from upstream — alpine has no kubectl package
RUN curl -fsSL "https://dl.k8s.io/release/v${KUBECTL_VERSION}/bin/linux/amd64/kubectl" -o /usr/local/bin/kubectl && \
    chmod +x /usr/local/bin/kubectl && \
    kubectl version --client=true

# Python deps — versions pinned in requirements.txt for Renovate
COPY requirements.txt /tmp/requirements.txt
RUN pip install --no-cache-dir --root-user-action=ignore -r /tmp/requirements.txt && \
    rm /tmp/requirements.txt

# Non-root user with a writable HOME so consumers don't need HOME=/tmp hacks.
# UID 65534 matches the existing dns-sync/sso-complete-setup pod securityContext.
RUN addgroup -g 65534 tooling 2>/dev/null || true && \
    adduser -D -u 65534 -G nobody -h /home/tooling tooling 2>/dev/null || \
    (mkdir -p /home/tooling && chown 65534:65534 /home/tooling)

ENV HOME=/home/tooling
USER 65534

WORKDIR /home/tooling
