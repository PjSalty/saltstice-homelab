# =============================================================================
# TrueNAS Provider Variables (PjSalty/truenas v1.10+)
# =============================================================================

variable "truenas_api_url" {
  description = "TrueNAS SCALE API base URL"
  type        = string
  default     = "https://truenas.example.com/api/v2.0"
  validation {
    condition     = can(regex("^https?://", var.truenas_api_url))
    error_message = "TrueNAS API URL must start with http:// or https://."
  }
}

variable "truenas_api_key" {
  description = "TrueNAS API key for authentication (generated in TrueNAS UI under Credentials > API Keys)"
  type        = string
  sensitive   = true
  validation {
    condition     = length(var.truenas_api_key) > 0
    error_message = "TrueNAS API key must not be empty."
  }
}

variable "truenas_user_passwords" {
  description = "Map of TrueNAS username to password for managed user accounts. Drawn from infrastructure.truenas.users.<name>.password in SOPS."
  type        = map(string)
  sensitive   = true
  default     = {}
}
