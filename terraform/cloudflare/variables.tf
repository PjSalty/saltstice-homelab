# =============================================================================
# Cloudflare Provider Variables
# =============================================================================

variable "cloudflare_api_token" {
  description = "Cloudflare API token with Zone:DNS:Edit and Account:Tunnel:Edit permissions"
  type        = string
  sensitive   = true
  validation {
    condition     = length(var.cloudflare_api_token) > 0
    error_message = "Cloudflare API token must not be empty."
  }
}

variable "cloudflare_account_id" {
  description = "Cloudflare account ID"
  type        = string
  validation {
    condition     = can(regex("^[a-f0-9]{32}$", var.cloudflare_account_id))
    error_message = "Cloudflare account ID must be a 32-character hex string."
  }
}

variable "cloudflare_zone_name" {
  description = "Primary DNS zone name"
  type        = string
  default     = "example.com"
  validation {
    condition     = can(regex("^[a-zA-Z0-9][a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}$", var.cloudflare_zone_name))
    error_message = "Zone name must be a valid domain name."
  }
}

variable "wan_ip" {
  description = "Current WAN IP address for A records (updated by cloudflare-dns-sync CronJob)"
  type        = string
  default     = "203.0.113.1" # RFC 5737 documentation IP — set per-environment via tfvars
  validation {
    condition     = can(regex("^((25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\\.){3}(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$", var.wan_ip))
    error_message = "WAN IP must be a valid IPv4 address."
  }
}
