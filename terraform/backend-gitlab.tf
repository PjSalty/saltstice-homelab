# ==============================================================================
# GitLab HTTP Backend for Terraform State
# ==============================================================================
# Stores Terraform state in GitLab for team collaboration and CI/CD
# Requires: TF_HTTP_ADDRESS, TF_HTTP_LOCK_ADDRESS, TF_HTTP_UNLOCK_ADDRESS,
#           TF_HTTP_USERNAME, TF_HTTP_PASSWORD environment variables
# ==============================================================================

# To migrate to GitLab backend:
# 1. Set environment variables (see scripts/setup-terraform-backend.sh)
# 2. Uncomment the terraform block below
# 3. Comment out the backend "local" block in main.tf
# 4. Run: terraform init -migrate-state

# terraform {
#   backend "http" {
#     # These values will be provided via environment variables:
#     # TF_HTTP_ADDRESS        = "https://gitlab.example.com/api/v4/projects/<PROJECT_ID>/terraform/state/homelab-infra"
#     # TF_HTTP_LOCK_ADDRESS   = "https://gitlab.example.com/api/v4/projects/<PROJECT_ID>/terraform/state/homelab-infra/lock"
#     # TF_HTTP_UNLOCK_ADDRESS = "https://gitlab.example.com/api/v4/projects/<PROJECT_ID>/terraform/state/homelab-infra/lock"
#     # TF_HTTP_USERNAME       = "root"
#     # TF_HTTP_PASSWORD = (set via environment variable)
#     # TF_HTTP_LOCK_METHOD    = "POST"
#     # TF_HTTP_UNLOCK_METHOD  = "DELETE"
#     # TF_HTTP_RETRY_WAIT_MIN = "5"
#   }
# }

# Alternative: S3-compatible backend (MinIO on TrueNAS)
# terraform {
#   backend "s3" {
#     bucket                      = "terraform-state"
#     key                         = "homelab/terraform.tfstate"
#     region                      = "us-east-1"
#     endpoint                    = "https://minio.example.com"
#     skip_credentials_validation = true
#     skip_metadata_api_check     = true
#     skip_region_validation      = true
#     force_path_style            = true
#   }
# }
