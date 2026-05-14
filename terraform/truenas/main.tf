# =============================================================================
# TrueNAS Provider — Full prod mirror via PjSalty/truenas v1.10+
# =============================================================================
# Imports the complete non-CSI TrueNAS configuration: datasets, NFS/SMB
# shares, snapshot tasks, scrub task, iSCSI static infra, alert services,
# users, and the system update config. Per-PV zvols + iSCSI extents +
# targetextents remain unmanaged (democratic-csi owns them dynamically).
#
# State backend: homelab-truenas-v2 (temporary — renamed to homelab-truenas
# after Phase B cutover retires truenas-legacy/).

terraform {
  required_version = ">= 1.5"
  required_providers {
    truenas = {
      source  = "PjSalty/truenas"
      version = "~> 1.10"
    }
  }
}

provider "truenas" {
  url                = var.truenas_api_url
  api_key            = var.truenas_api_key
  destroy_protection = true
  request_timeout    = "120s"
}

# =============================================================================
# Datasets — top-level (no parent_dataset)
# =============================================================================

resource "truenas_dataset" "kubernetes" {
  pool        = "tank"
  name        = "kubernetes"
  compression = "LZ4"
  atime       = "OFF"
  record_size = "128K"
}

resource "truenas_dataset" "iscsi" {
  pool        = "tank"
  name        = "iscsi"
  compression = "LZ4"
  atime       = "OFF"
  record_size = "128K"
  comments    = "Kubernetes iSCSI block storage via democratic-csi"
}

resource "truenas_dataset" "media" {
  pool        = "tank"
  name        = "media"
  compression = "LZ4"
  atime       = "OFF"
  record_size = "1M"
}

resource "truenas_dataset" "minio" {
  pool        = "tank"
  name        = "minio"
  compression = "LZ4"
  atime       = "OFF"
  record_size = "128K"
}

resource "truenas_dataset" "gitlab" {
  pool        = "tank"
  name        = "gitlab"
  compression = "LZ4"
  atime       = "OFF"
  record_size = "128K"
}

resource "truenas_dataset" "terraform_state" {
  pool        = "tank"
  name        = "terraform-state"
  compression = "LZ4"
  atime       = "OFF"
  record_size = "128K"
}

resource "truenas_dataset" "shared" {
  pool        = "tank"
  name        = "shared"
  compression = "LZ4"
  atime       = "OFF"
  record_size = "1M"
}

resource "truenas_dataset" "backups" {
  pool        = "tank"
  name        = "backups"
  compression = "LZ4"
  atime       = "OFF"
  record_size = "128K"
}

resource "truenas_dataset" "downloads" {
  pool        = "tank"
  name        = "downloads"
  compression = "LZ4"
  atime       = "OFF"
  record_size = "128K"
}

resource "truenas_dataset" "harbor" {
  pool        = "tank"
  name        = "harbor"
  compression = "LZ4"
  atime       = "OFF"
  record_size = "128K"
}

resource "truenas_dataset" "users" {
  pool        = "tank"
  name        = "users"
  compression = "LZ4"
  atime       = "OFF"
  record_size = "128K"
}

# =============================================================================
# Datasets — children (have parent_dataset)
# =============================================================================

resource "truenas_dataset" "iscsi_volumes" {
  pool           = "tank"
  name           = "volumes"
  parent_dataset = "iscsi"
  compression    = "LZ4"
  atime          = "OFF"
  record_size    = "128K"
  comments       = "Kubernetes iSCSI block storage via democratic-csi"
}

resource "truenas_dataset" "backups_seaweedfs" {
  pool           = "tank"
  name           = "seaweedfs"
  parent_dataset = "backups"
  compression    = "LZ4"
  atime          = "OFF"
  record_size    = "128K"
  comments       = "SeaweedFS NFS backup destination for K8s CronJob"
}

resource "truenas_dataset" "user_renea" {
  pool           = "tank"
  name           = "eve"
  parent_dataset = "users"
  compression    = "LZ4"
  atime          = "OFF"
  record_size    = "128K"
}

resource "truenas_dataset" "user_matthew" {
  pool           = "tank"
  name           = "dave"
  parent_dataset = "users"
  compression    = "LZ4"
  atime          = "OFF"
  record_size    = "128K"
}

resource "truenas_dataset" "user_michael" {
  pool           = "tank"
  name           = "alice"
  parent_dataset = "users"
  compression    = "LZ4"
  atime          = "OFF"
  record_size    = "128K"
}

resource "truenas_dataset" "user_timm" {
  pool           = "tank"
  name           = "carol"
  parent_dataset = "users"
  compression    = "LZ4"
  atime          = "OFF"
  record_size    = "128K"
}

resource "truenas_dataset" "user_dre" {
  pool           = "tank"
  name           = "bob"
  parent_dataset = "users"
  compression    = "LZ4"
  atime          = "OFF"
  record_size    = "128K"
}

# =============================================================================
# NFS Shares
# =============================================================================

resource "truenas_share_nfs" "kubernetes" {
  path         = "/mnt/tank/kubernetes"
  comment      = "Kubernetes PV storage"
  mapall_user  = "root"
  mapall_group = "root"
  networks     = ["<mgmt-ip>/24", "<vlan-cidr>", "10.x0.0/24", "<vlan-cidr>", "<vlan-cidr>"]
}

resource "truenas_share_nfs" "media" {
  path         = "/mnt/tank/media"
  comment      = "Media NFS share"
  mapall_user  = "root"
  mapall_group = "root"
  networks     = ["<mgmt-ip>/24", "<vlan-cidr>", "10.x0.0/24", "<vlan-cidr>", "<vlan-cidr>"]
}

resource "truenas_share_nfs" "media_drop" {
  path         = "/mnt/tank/users/bob/media-drop"
  comment      = "Media drop folder - K8s CronJob access"
  mapall_user  = "root"
  mapall_group = "root"
}

resource "truenas_share_nfs" "downloads" {
  path         = "/mnt/tank/downloads"
  mapall_user  = "root"
  mapall_group = "root"
}

resource "truenas_share_nfs" "backups_seaweedfs" {
  path         = "/mnt/tank/backups/seaweedfs"
  comment      = "SeaweedFS backup for K8s CronJob"
  mapall_user  = "nobody"
  mapall_group = "nogroup"
  networks     = ["10.x0.0/24", "<vlan-cidr>"]
}

# =============================================================================
# SMB Shares
# =============================================================================

resource "truenas_share_smb" "alice" {
  path    = "/mnt/tank/users/alice"
  name    = "alice"
  comment = "Alice home directory"
}

resource "truenas_share_smb" "bob" {
  path    = "/mnt/tank/users/bob"
  name    = "bob"
  comment = "Bob home directory"
}

resource "truenas_share_smb" "carol" {
  path    = "/mnt/tank/users/carol"
  name    = "carol"
  comment = "Carol home directory"
}

resource "truenas_share_smb" "dave" {
  path    = "/mnt/tank/users/dave"
  name    = "dave"
  comment = "Dave home directory"
}

resource "truenas_share_smb" "eve" {
  path    = "/mnt/tank/users/eve"
  name    = "eve"
  comment = "Eve home directory"
}

resource "truenas_share_smb" "tank" {
  path    = "/mnt/tank"
  name    = "tank"
  comment = "Full ZFS tank pool access"
}

# =============================================================================
# iSCSI Portal (static infra — per-PV targets/extents are CSI-managed)
# =============================================================================

resource "truenas_iscsi_portal" "k8s" {
  comment = "Kubernetes democratic-csi portal"
  listen = [{
    ip = "0.0.0.0"
  }]
}

# =============================================================================
# Scrub Task
# =============================================================================

resource "truenas_scrub_task" "tank" {
  pool            = 1
  threshold       = 35
  enabled         = true
  schedule_minute = "00"
  schedule_hour   = "00"
  schedule_dom    = "*"
  schedule_month  = "*"
  schedule_dow    = "7"
}

# =============================================================================
# Alert Services
# =============================================================================

resource "truenas_alert_service" "snmp_trap" {
  name    = "SNMP Trap"
  type    = "SNMPTrap"
  enabled = true
  level   = "WARNING"
  settings_json = jsonencode({
    host      = "localhost"
    port      = 162
    v3        = false
    community = "public"
  })
}

resource "truenas_alert_service" "mail" {
  name    = "E-Mail"
  type    = "Mail"
  enabled = true
  level   = "WARNING"
  settings_json = jsonencode({
    email = ""
  })
}

# =============================================================================
# Snapshot Tasks
# =============================================================================

# --- tank/users: hourly + daily + weekly (recursive) ---

resource "truenas_snapshot_task" "users_hourly" {
  dataset         = "tank/users"
  recursive       = true
  lifetime_value  = 24
  lifetime_unit   = "HOUR"
  naming_schema   = "hourly-%Y-%m-%d_%H-%M"
  enabled         = true
  allow_empty     = false
  schedule_minute = "0"
  schedule_hour   = "*"
  schedule_dom    = "*"
  schedule_month  = "*"
  schedule_dow    = "*"
}

resource "truenas_snapshot_task" "users_daily" {
  dataset         = "tank/users"
  recursive       = true
  lifetime_value  = 7
  lifetime_unit   = "DAY"
  naming_schema   = "daily-%Y-%m-%d_%H-%M"
  enabled         = true
  allow_empty     = false
  schedule_minute = "0"
  schedule_hour   = "0"
  schedule_dom    = "*"
  schedule_month  = "*"
  schedule_dow    = "*"
}

resource "truenas_snapshot_task" "users_weekly" {
  dataset         = "tank/users"
  recursive       = true
  lifetime_value  = 4
  lifetime_unit   = "WEEK"
  naming_schema   = "weekly-%Y-%m-%d_%H-%M"
  enabled         = true
  allow_empty     = false
  schedule_minute = "0"
  schedule_hour   = "1"
  schedule_dom    = "*"
  schedule_month  = "*"
  schedule_dow    = "0"
}

# --- tank/kubernetes: hourly + daily (non-recursive) ---

resource "truenas_snapshot_task" "kubernetes_hourly" {
  dataset         = "tank/kubernetes"
  recursive       = false
  lifetime_value  = 24
  lifetime_unit   = "HOUR"
  naming_schema   = "hourly-%Y-%m-%d_%H-%M"
  enabled         = true
  allow_empty     = false
  schedule_minute = "15"
  schedule_hour   = "*"
  schedule_dom    = "*"
  schedule_month  = "*"
  schedule_dow    = "*"
}

resource "truenas_snapshot_task" "kubernetes_daily" {
  dataset         = "tank/kubernetes"
  recursive       = false
  lifetime_value  = 7
  lifetime_unit   = "DAY"
  naming_schema   = "daily-%Y-%m-%d_%H-%M"
  enabled         = true
  allow_empty     = false
  schedule_minute = "15"
  schedule_hour   = "0"
  schedule_dom    = "*"
  schedule_month  = "*"
  schedule_dow    = "*"
}

# --- tank/iscsi: hourly + daily (recursive) ---

resource "truenas_snapshot_task" "iscsi_hourly" {
  dataset         = "tank/iscsi"
  recursive       = true
  lifetime_value  = 24
  lifetime_unit   = "HOUR"
  naming_schema   = "hourly-%Y-%m-%d_%H-%M"
  enabled         = true
  allow_empty     = false
  schedule_minute = "30"
  schedule_hour   = "*"
  schedule_dom    = "*"
  schedule_month  = "*"
  schedule_dow    = "*"
}

resource "truenas_snapshot_task" "iscsi_daily" {
  dataset         = "tank/iscsi"
  recursive       = true
  lifetime_value  = 7
  lifetime_unit   = "DAY"
  naming_schema   = "daily-%Y-%m-%d_%H-%M"
  enabled         = true
  allow_empty     = false
  schedule_minute = "30"
  schedule_hour   = "0"
  schedule_dom    = "*"
  schedule_month  = "*"
  schedule_dow    = "*"
}

# --- tank/media: daily + weekly (non-recursive) ---

resource "truenas_snapshot_task" "media_daily" {
  dataset         = "tank/media"
  recursive       = false
  lifetime_value  = 7
  lifetime_unit   = "DAY"
  naming_schema   = "daily-%Y-%m-%d_%H-%M"
  enabled         = true
  allow_empty     = false
  schedule_minute = "45"
  schedule_hour   = "2"
  schedule_dom    = "*"
  schedule_month  = "*"
  schedule_dow    = "*"
}

resource "truenas_snapshot_task" "media_weekly" {
  dataset         = "tank/media"
  recursive       = false
  lifetime_value  = 4
  lifetime_unit   = "WEEK"
  naming_schema   = "weekly-%Y-%m-%d_%H-%M"
  enabled         = true
  allow_empty     = false
  schedule_minute = "45"
  schedule_hour   = "3"
  schedule_dom    = "*"
  schedule_month  = "*"
  schedule_dow    = "0"
}

# =============================================================================
# System Update Control
# =============================================================================

resource "truenas_system_update" "prod" {
  auto_download = true
  train         = "TrueNAS-SCALE-Fangtooth"
}

# =============================================================================
# CVE-2026-31431 mitigation -- algif_aead blacklist
# =============================================================================
# TrueNAS SCALE rootfs is reset on each boot, so the modprobe.d drop has to be
# re-applied at PREINIT. The install /bin/true line stops any in-kernel auto-load
# (AF_ALG path), and the rmmod handles the running kernel if the module is live.
# Remove this resource once Debian trixie-security ships the fixed kernel.

resource "truenas_init_script" "algif_aead_blacklist" {
  type    = "COMMAND"
  when    = "PREINIT"
  enabled = true
  timeout = 30
  comment = "CVE-2026-31431 algif_aead blacklist (remove after kernel fix)"
  command = "mkdir -p /etc/modprobe.d && printf 'blacklist algif_aead\\ninstall algif_aead /bin/true\\n' > /etc/modprobe.d/blacklist-algif-aead.conf && modprobe -r algif_aead 2>/dev/null || true"
}
