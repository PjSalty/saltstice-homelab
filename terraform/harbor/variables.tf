# =============================================================================
# Harbor Provider Variables
# =============================================================================

variable "harbor_url" {
  description = "Harbor registry URL"
  type        = string
  default     = "https://harbor.example.com"
  validation {
    condition     = can(regex("^https?://", var.harbor_url))
    error_message = "Harbor URL must start with http:// or https://."
  }
}

variable "harbor_admin_password" {
  description = "Harbor admin password for API authentication"
  type        = string
  sensitive   = true
  validation {
    condition     = length(var.harbor_admin_password) >= 8
    error_message = "Harbor admin password must be at least 8 characters."
  }
}

variable "harbor_oidc_client_id" {
  description = "OIDC client ID for Authentik SSO integration"
  type        = string
  default     = "harbor-sso"
  validation {
    condition     = length(var.harbor_oidc_client_id) > 0
    error_message = "Harbor OIDC client ID must not be empty."
  }
}

variable "harbor_oidc_client_secret" {
  description = "OIDC client secret from Authentik"
  type        = string
  sensitive   = true
  validation {
    condition     = length(var.harbor_oidc_client_secret) > 0
    error_message = "Harbor OIDC client secret must not be empty."
  }
}

variable "harbor_k8s_pull_password" {
  description = "Password for robot$<pull-account> account (used by K8s containerd)"
  type        = string
  sensitive   = true
  validation {
    condition     = length(var.harbor_k8s_pull_password) > 0
    error_message = "Harbor K8s pull password must not be empty."
  }
}

variable "harbor_automation_password" {
  description = "Password for robot$<svc-account> account (used by CI for image push and by K8s for image pull). Sourced from credentials.sops.yaml infrastructure.harbor.robot_password."
  type        = string
  sensitive   = true
  validation {
    condition     = length(var.harbor_automation_password) >= 16
    error_message = "Harbor automation password must be at least 16 characters."
  }
}
