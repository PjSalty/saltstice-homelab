# =============================================================================
# Import blocks for existing GitLab resources
# =============================================================================

# terraform-provider-truenas was created via API before being added to TF
import {
  to = gitlab_project.repos["terraform-provider-truenas"]
  id = "16"
}
