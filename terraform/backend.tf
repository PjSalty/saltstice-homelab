# ==============================================================================
# GitLab HTTP Backend Configuration
# ==============================================================================
# This backend stores Terraform state in GitLab's managed Terraform state
# Environment variables required:
#   TF_HTTP_ADDRESS, TF_HTTP_LOCK_ADDRESS, TF_HTTP_UNLOCK_ADDRESS
#   TF_HTTP_USERNAME, TF_HTTP_PASSWORD
#
# To use:
#   source .gitlab-backend.env
#   terraform init
#   terraform plan
# ==============================================================================

terraform {
  backend "http" {
    # All other configuration via environment variables
    # See: scripts/migrate-terraform-to-gitlab.sh

    skip_cert_verification = false
  }
}
