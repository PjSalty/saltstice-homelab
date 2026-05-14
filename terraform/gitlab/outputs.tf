# =============================================================================
# GitLab Provider Outputs
# =============================================================================

output "infrastructure_group_id" {
  description = "Infrastructure group ID"
  value       = gitlab_group.infrastructure.id
}

output "project_ids" {
  description = "Map of infrastructure project name to numeric ID"
  value       = { for k, v in gitlab_project.repos : k => v.id }
}

output "project_ssh_urls" {
  description = "Map of project name to SSH clone URL"
  value       = { for k, v in gitlab_project.repos : k => v.ssh_url_to_repo }
}

output "project_count" {
  description = "Total number of GitLab projects managed by Terraform"
  value       = length(gitlab_project.repos)
}

output "group_count" {
  description = "Total number of GitLab groups managed by Terraform"
  value       = 1 # infrastructure
}
