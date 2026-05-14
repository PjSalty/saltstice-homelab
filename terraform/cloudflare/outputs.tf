# =============================================================================
# Cloudflare Provider Outputs
# =============================================================================

output "zone_id" {
  description = "Cloudflare zone ID for example.com"
  value       = data.cloudflare_zone.main.id
}

output "dns_record_count" {
  description = "Number of DNS records managed by Terraform in example.com"
  value = length(concat(
    [
      cloudflare_dns_record.jellyfin.id,
      cloudflare_dns_record.salt.id,
      cloudflare_dns_record.saltstice_www.id,
    ],
    [for r in cloudflare_dns_record.saltstice_apex : r.id],
  ))
}
