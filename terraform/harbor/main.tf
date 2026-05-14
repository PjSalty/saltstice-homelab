# =============================================================================
# Harbor Provider — Projects, Registries, Robot Accounts, OIDC, Scanning
# =============================================================================
# Migrates API configuration from Ansible role (roles/harbor/tasks/main.yml
# lines 92-444) to Terraform. Ansible continues to manage Docker Compose
# deployment (lines 1-91).

terraform {
  required_version = ">= 1.0"
  required_providers {
    harbor = {
      source  = "goharbor/harbor"
      version = "~> 3.11"
    }
  }
}

provider "harbor" {
  url      = var.harbor_url
  username = "admin"
  password = var.harbor_admin_password
  insecure = false
}

# =============================================================================
# Proxy Cache Registry Endpoints (upstream registries)
# =============================================================================

locals {
  # Map key = project name (-proxy suffix), registry_name = existing Harbor registry name
  proxy_registries = {
    dockerhub-proxy  = { registry_name = "dockerhub", url = "https://hub.docker.com", type = "docker-hub" }
    ghcr-proxy       = { registry_name = "ghcr", url = "https://ghcr.io", type = "github" }
    gcr-mirror-proxy = { registry_name = "mirror-gcr-io", url = "https://mirror.gcr.io", type = "docker-registry" }
    quay-proxy       = { registry_name = "quay-io", url = "https://quay.io", type = "quay" }
    k8s-proxy        = { registry_name = "registry-k8s-io", url = "https://registry.k8s.io", type = "docker-registry" }
    nvcr-proxy       = { registry_name = "nvcr-io", url = "https://nvcr.io", type = "docker-registry" }
    kyverno-proxy    = { registry_name = "kyverno-io", url = "https://reg.kyverno.io", type = "docker-registry" }
    gcp-proxy        = { registry_name = "us-docker-pkg", url = "https://us-docker.pkg.dev", type = "docker-registry" }
    eso-proxy        = { registry_name = "oci-external-secrets", url = "https://oci.external-secrets.io", type = "docker-registry" }
  }
}

resource "harbor_registry" "proxy" {
  for_each = local.proxy_registries

  provider_name = each.value.type
  name          = each.value.registry_name
  endpoint_url  = each.value.url
  insecure      = false
}

# =============================================================================
# Standard Projects (private, auto-scan)
# =============================================================================

resource "harbor_project" "infrastructure" {
  name                   = "infrastructure"
  public                 = false
  vulnerability_scanning = true
  storage_quota          = 100 # GB
}

resource "harbor_project" "tools" {
  name                   = "tools"
  public                 = false
  vulnerability_scanning = true
  storage_quota          = 20 # GB
}

# =============================================================================
# Proxy Cache Projects (public for containerd pulls, linked to registries)
# =============================================================================

resource "harbor_project" "proxy" {
  for_each = harbor_registry.proxy

  name                   = each.key
  public                 = true
  vulnerability_scanning = true
  registry_id            = each.value.registry_id
}

# =============================================================================
# Robot Account — system-level automation with push/pull
# =============================================================================

resource "harbor_robot_account" "automation" {
  name        = "automation"
  description = "System-level automation account for CI/CD and containerd pulls"
  level       = "system"
  duration    = -1 # Never expires

  # Write-only attribute (provider v3.10+). Unlike the legacy `secret`, this
  # value is never stored in state, and the secret_wo_version is what triggers
  # a re-apply. The version must be a number — we hash the password and take
  # the first 8 hex chars as a 32-bit int so any SSOT rotation auto-bumps the
  # version and pushes the new secret to Harbor on next apply.
  secret_wo         = var.harbor_automation_password
  secret_wo_version = parseint(substr(sha256(var.harbor_automation_password), 0, 8), 16)

  permissions {
    access {
      action   = "push"
      resource = "repository"
    }
    access {
      action   = "pull"
      resource = "repository"
    }
    access {
      action   = "read"
      resource = "artifact"
    }
    access {
      action   = "list"
      resource = "tag"
    }
    access {
      action   = "create"
      resource = "tag"
    }
    access {
      action   = "list"
      resource = "repository"
    }
    kind      = "project"
    namespace = "*"
  }

  lifecycle {
    prevent_destroy = true
  }
}

# Robot Account — K8s containerd pull-only (used by all RKE2 nodes)
# Configured in k8s_cluster.yml rke2_custom_registry_configs
resource "harbor_robot_account" "k8s_pull" {
  name        = "k8s-pull"
  description = "Pull-only account for K8s containerd registry mirrors"
  level       = "system"
  duration    = -1 # Never expires
  secret      = var.harbor_k8s_pull_password

  permissions {
    access {
      action   = "pull"
      resource = "repository"
    }
    access {
      action   = "read"
      resource = "artifact"
    }
    access {
      action   = "list"
      resource = "repository"
    }
    access {
      action   = "list"
      resource = "tag"
    }
    kind      = "project"
    namespace = "*"
  }

  lifecycle {
    prevent_destroy = true
  }
}

# =============================================================================
# OIDC Authentication (Authentik SSO)
# =============================================================================

resource "harbor_config_auth" "oidc" {
  auth_mode          = "oidc_auth"
  primary_auth_mode  = true
  oidc_name          = "Authentik"
  oidc_endpoint      = "https://auth.example.com/application/o/harbor/"
  oidc_client_id     = var.harbor_oidc_client_id
  oidc_client_secret = var.harbor_oidc_client_secret
  oidc_scope         = "openid,profile,email"
  oidc_verify_cert   = true
  oidc_auto_onboard  = true
  oidc_groups_claim  = "groups"
  oidc_admin_group   = "platform-admins"
  oidc_user_claim    = "preferred_username"
}

# Vulnerability scanning schedule omitted — requires Trivy scanner to be
# registered in Harbor first (handled by Harbor's install.sh during deploy).
# Can be added once scanner is confirmed active.

# =============================================================================
# Additional Projects (previously created manually via API)
# =============================================================================

resource "harbor_project" "homelab" {
  name                   = "homelab"
  public                 = false
  vulnerability_scanning = true
  storage_quota          = 50 # GB
}

# Note: harbor_project_quota does not exist as a standalone resource in
# goharbor/harbor ~> 3.11. Storage quotas are set via the storage_quota
# argument on each harbor_project resource (in GB; -1 = unlimited).

# =============================================================================
# Tag Retention Policies
# =============================================================================

# Keep the 20 most recently pushed images across all repos in infrastructure
resource "harbor_retention_policy" "infrastructure" {
  scope    = harbor_project.infrastructure.project_id
  schedule = "Daily"

  rule {
    repo_matching        = "**"
    tag_matching         = "**"
    most_recently_pushed = 20
    untagged_artifacts   = false
  }
}

# Keep the 10 most recently pushed images across all repos in tools
resource "harbor_retention_policy" "tools" {
  scope    = harbor_project.tools.project_id
  schedule = "Daily"

  rule {
    repo_matching        = "**"
    tag_matching         = "**"
    most_recently_pushed = 10
    untagged_artifacts   = false
  }
}

# Keep the 30 most recently pushed images in homelab
resource "harbor_retention_policy" "homelab" {
  scope    = harbor_project.homelab.project_id
  schedule = "Daily"

  rule {
    repo_matching        = "**"
    tag_matching         = "**"
    most_recently_pushed = 30
    untagged_artifacts   = false
  }
}

# =============================================================================
# Garbage Collection Schedule
# =============================================================================

# Weekly GC removes unreferenced blobs and untagged artifacts
resource "harbor_garbage_collection" "weekly" {
  schedule        = "Weekly"
  delete_untagged = true
  workers         = 1
}
