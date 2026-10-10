variable "name" {
  type = string
}

variable "resource_group_name" {
  type = string
}

variable "location" {
  type = string
}

variable "cmk_identity_id" {
  type = string
}

variable "cmk_versionless_key_id" {
  type = string
}

variable "private_endpoint_subnet_id" {
  type = string
}

variable "private_dns_zone_id" {
  description = "privatelink.documents.azure.com zone id."
  type        = string
}

variable "tier" {
  type = string
}

variable "continuous_backup_tier" {
  description = "Continuous7Days or Continuous30Days; tier1 should use Continuous30Days (spec section 12.1)."
  type        = string
  default     = "Continuous30Days"
}

variable "geo_locations" {
  description = "List of { location, failover_priority } for multi-region; tier1 should include the DR region."
  type = list(object({
    location          = string
    failover_priority = number
  }))
}

variable "log_analytics_workspace_id" {
  type = string
}

variable "tags" {
  type    = map(string)
  default = {}
}
