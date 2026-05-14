# =============================================================================
# Authentik Provider Variables
# =============================================================================

variable "authentik_url" {
  description = "Authentik instance URL"
  type        = string
  default     = "https://auth.example.com"
  validation {
    condition     = can(regex("^https?://", var.authentik_url))
    error_message = "Authentik URL must start with http:// or https://."
  }
}

variable "authentik_api_token" {
  description = "Authentik admin API token"
  type        = string
  sensitive   = true
  validation {
    condition     = length(var.authentik_api_token) > 0
    error_message = "Authentik API token must not be empty."
  }
}

variable "oauth2_client_secrets" {
  description = "Map of app slug to OIDC client secret"
  type        = map(string)
  sensitive   = true
  default     = {}
}

variable "user_passwords" {
  description = "Map of user key to initial password (ignored after first apply)"
  type        = map(string)
  sensitive   = true
  default     = {}
}
