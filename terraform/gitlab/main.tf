# =============================================================================
# GitLab Provider — Projects, Groups, Branch Protection, CI Variables
# =============================================================================

terraform {
  required_version = ">= 1.0"
  required_providers {
    gitlab = {
      source  = "gitlabhq/gitlab"
      version = "~> 18.0"
    }
  }
}

provider "gitlab" {
  base_url = var.gitlab_url
  token    = var.gitlab_api_token
  insecure = false
}

# =============================================================================
# Infrastructure Group (already exists — imported)
# =============================================================================

resource "gitlab_group" "infrastructure" {
  name             = "infrastructure"
  path             = "infrastructure"
  description      = "Homelab infrastructure-as-code repositories"
  visibility_level = "internal" # Required for cross-project CI template includes

  lifecycle {
    prevent_destroy = true
  }
}

# =============================================================================
# Projects
# =============================================================================

locals {
  # Example project map. Replace with your actual project list — the pattern
  # is one repo per key, with description + visibility per project. The
  # `require_pipeline = false` override on the secrets project allows pushes
  # without a passing pipeline (since secrets repos often don't run CI).
  projects = {
    repo-1 = {
      description      = "Example: SOPS-encrypted Kubernetes secrets"
      visibility       = "private"
      require_pipeline = false
    }
    repo-2 = {
      description = "Example: Terraform modules"
      visibility  = "private"
    }
    repo-3 = {
      description = "Example: Ansible playbooks and roles"
      visibility  = "private"
    }
    repo-4 = {
      description = "Example: Kubernetes manifests for FluxCD"
      visibility  = "private"
    }
    repo-5 = {
      description = "Example: Reusable GitLab CI/CD pipeline templates"
      visibility  = "internal"
    }
  }
}

resource "gitlab_project" "repos" {
  for_each = local.projects

  name                                  = each.key
  namespace_id                          = gitlab_group.infrastructure.id
  description                           = each.value.description
  visibility_level                      = each.value.visibility
  default_branch                        = "main"
  merge_method                          = "rebase_merge"
  squash_option                         = "default_on"
  remove_source_branch_after_merge      = true
  only_allow_merge_if_pipeline_succeeds = lookup(each.value, "require_pipeline", true)
  shared_runners_enabled                = true
  wiki_access_level                     = "disabled"
  issues_access_level                   = "enabled"
  snippets_access_level                 = "disabled"
  pages_access_level                    = "private"

  lifecycle {
    prevent_destroy = true
    ignore_changes = [
      # These may be changed via GitLab UI — don't drift on cosmetic settings
      avatar_hash,
      ci_config_path,
    ]
  }
}

# =============================================================================
# Group Membership — Salty is Owner
# =============================================================================

data "gitlab_user" "salty" {
  username = "Salty"
}

resource "gitlab_group_membership" "infra_salty" {
  group_id     = gitlab_group.infrastructure.id
  user_id      = data.gitlab_user.salty.id
  access_level = "owner"
}

# =============================================================================
# Branch Protection — main branch on all projects
# =============================================================================

resource "gitlab_branch_protection" "main" {
  for_each = gitlab_project.repos

  project                      = each.value.id
  branch                       = "main"
  push_access_level            = "maintainer"
  merge_access_level           = "maintainer"
  unprotect_access_level       = "maintainer"
  allow_force_push             = false
  code_owner_approval_required = false
}

# =============================================================================
# Group CI/CD Variables — infrastructure group
# =============================================================================
#
# Non-sensitive, non-multiline variables only. The following vars remain
# managed manually in the GitLab UI because they contain sensitive or
# multiline content that cannot safely live in Terraform state:
#
#   SOPS_AGE_KEY       — multiline Age private key, cannot be masked
#   SSH_PRIVATE_KEY    — multiline RSA/ED25519 key, cannot be masked
#   HARBOR_PASSWORD    — rotated by credential management system
#   KUBE_CONFIG        — multiline base64 kubeconfig, cannot be masked
#
# These are intentionally excluded to avoid storing sensitive data in
# TF state and to allow the credential rotation playbook to update them
# without a Terraform run.

resource "gitlab_group_variable" "infra_vars" {
  for_each = {
    HARBOR_REGISTRY = {
      value     = "harbor.example.com"
      protected = false
      masked    = false
    }
    HARBOR_USERNAME = {
      value     = "robot$<svc-account>"
      protected = true
      masked    = false
    }
    ANSIBLE_RUNNER_IMAGE = {
      value     = "harbor.example.com/tools/ansible-runner:stable"
      protected = false
      masked    = false
    }
  }

  group             = gitlab_group.infrastructure.id
  key               = each.key
  value             = each.value.value
  protected         = each.value.protected
  masked            = each.value.masked
  environment_scope = "*"
}

# =============================================================================
# Project Labels — applied to all infrastructure projects
# =============================================================================

locals {
  standard_labels = {
    bug = {
      color       = "#CC0000"
      description = "Something isn't working"
    }
    feature = {
      color       = "#428BCA"
      description = "New functionality"
    }
    enhancement = {
      color       = "#5CB85C"
      description = "Improvement to existing feature"
    }
    docs = {
      color       = "#34495E"
      description = "Documentation changes"
    }
    ci-cd = {
      color       = "#E67E22"
      description = "Pipeline and CI/CD changes"
    }
    security = {
      color       = "#9B59B6"
      description = "Security-related changes"
    }
  }

  # Cartesian product: all infrastructure projects × all labels
  infra_project_labels = {
    for pair in setproduct(keys(local.projects), keys(local.standard_labels)) :
    "${pair[0]}--${pair[1]}" => {
      project_id  = gitlab_project.repos[pair[0]].id
      label_name  = pair[1]
      color       = local.standard_labels[pair[1]].color
      description = local.standard_labels[pair[1]].description
    }
  }
}

resource "gitlab_project_label" "infra_labels" {
  for_each = local.infra_project_labels

  project     = each.value.project_id
  name        = each.value.label_name
  color       = each.value.color
  description = each.value.description
}
