# =============================================================================
# Harbor Provider Outputs
# =============================================================================

output "robot_account_name" {
  description = "Robot account full name (robot$<svc-account>)"
  value       = harbor_robot_account.automation.full_name
}

output "robot_account_secret" {
  description = "Robot account secret for container registry authentication"
  value       = harbor_robot_account.automation.secret
  sensitive   = true
}

output "project_ids" {
  description = "Map of project name to numeric ID"
  value = merge(
    { infrastructure = harbor_project.infrastructure.project_id },
    { tools = harbor_project.tools.project_id },
    { homelab = harbor_project.homelab.project_id },
    { for k, v in harbor_project.proxy : k => v.project_id },
  )
}

output "registry_ids" {
  description = "Map of registry name to numeric ID"
  value       = { for k, v in harbor_registry.proxy : k => v.registry_id }
}

output "project_count" {
  description = "Total number of Harbor projects managed by Terraform"
  value       = 3 + length(harbor_project.proxy)
}

output "registry_count" {
  description = "Total number of proxy cache registries"
  value       = length(harbor_registry.proxy)
}

output "robot_account_count" {
  description = "Total number of robot accounts managed by Terraform"
  value       = 2 # automation + k8s-pull
}

output "retention_policy_ids" {
  description = "Map of project name to retention policy ID"
  value = {
    infrastructure = harbor_retention_policy.infrastructure.id
    tools          = harbor_retention_policy.tools.id
    homelab        = harbor_retention_policy.homelab.id
  }
}
