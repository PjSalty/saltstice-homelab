# =============================================================================
# Import blocks for existing Harbor resources
# These are idempotent — TF skips import if resource is already in state.
# Remove this file once all imports are complete and plans show 0 changes.
# =============================================================================

# --- Registries (path format: /registries/{id}) ---
import {
  to = harbor_registry.proxy["dockerhub-proxy"]
  id = "/registries/1"
}
import {
  to = harbor_registry.proxy["ghcr-proxy"]
  id = "/registries/2"
}
import {
  to = harbor_registry.proxy["quay-proxy"]
  id = "/registries/3"
}
import {
  to = harbor_registry.proxy["k8s-proxy"]
  id = "/registries/4"
}
import {
  to = harbor_registry.proxy["nvcr-proxy"]
  id = "/registries/5"
}
import {
  to = harbor_registry.proxy["kyverno-proxy"]
  id = "/registries/6"
}
import {
  to = harbor_registry.proxy["gcr-mirror-proxy"]
  id = "/registries/7"
}
import {
  to = harbor_registry.proxy["gcp-proxy"]
  id = "/registries/8"
}
import {
  to = harbor_registry.proxy["eso-proxy"]
  id = "/registries/9"
}

# --- Standard Projects ---
import {
  to = harbor_project.infrastructure
  id = "/projects/4"
}
import {
  to = harbor_project.tools
  id = "/projects/5"
}

# --- Proxy Cache Projects (only import those that exist) ---
import {
  to = harbor_project.proxy["dockerhub-proxy"]
  id = "/projects/6"
}
import {
  to = harbor_project.proxy["ghcr-proxy"]
  id = "/projects/7"
}
import {
  to = harbor_project.proxy["quay-proxy"]
  id = "/projects/33"
}
import {
  to = harbor_project.proxy["k8s-proxy"]
  id = "/projects/34"
}
import {
  to = harbor_project.proxy["kyverno-proxy"]
  id = "/projects/38"
}
# nvcr-proxy, gcr-mirror-proxy, gcp-proxy, eso-proxy do not exist in Harbor yet — TF will create them
# Note: quay-proxy project does not exist yet — TF will create it

# --- Robot Accounts ---
import {
  to = harbor_robot_account.automation
  id = "/robots/1"
}
import {
  to = harbor_robot_account.k8s_pull
  id = "/robots/23"
}

# --- OIDC Auth Config ---
import {
  to = harbor_config_auth.oidc
  id = "/configuration/auth"
}

# --- Additional Projects (created manually via API) ---
# homelab: may or may not exist — TF will create if absent
# TODO: Confirm numeric project IDs via Harbor API before applying:
#   curl -s -u admin:$HARBOR_PASS https://harbor.example.com/api/v2.0/projects | jq '.[] | {name,id}'
# Uncomment the import blocks below once IDs are confirmed:
#
# import {
#   to = harbor_project.homelab
#   id = "/projects/XX"  # Replace XX with actual ID; omit if project doesn't exist yet
# }
