# =============================================================================
# GitLab Provider Variables
# =============================================================================

variable "gitlab_url" {
  description = "GitLab instance URL"
  type        = string
  default     = "https://gitlab.example.com"
  validation {
    condition     = can(regex("^https?://", var.gitlab_url))
    error_message = "GitLab URL must start with http:// or https://."
  }
}

variable "gitlab_api_token" {
  description = "GitLab admin API token for Terraform management"
  type        = string
  sensitive   = true
  validation {
    condition     = can(regex("^glpat-", var.gitlab_api_token))
    error_message = "GitLab API token must be a personal access token (starts with 'glpat-')."
  }
}

