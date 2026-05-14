# =============================================================================
# Authentik Provider Outputs
# =============================================================================

output "user_count" {
  description = "Number of managed Authentik users"
  value       = length(authentik_user.users)
}

output "oauth2_app_count" {
  description = "Number of OAuth2 SSO applications"
  value       = length(authentik_provider_oauth2.apps)
}

output "proxy_app_count" {
  description = "Number of proxy-auth SSO applications"
  value       = length(authentik_provider_proxy.apps)
}
