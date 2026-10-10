variable "name" {
  type = string
}

variable "resource_group_name" {
  type = string
}

variable "location" {
  type = string
}

variable "pg_version" {
  type    = string
  default = "16" # TODO(verify): confirm latest supported Flexible Server major version at implementation time
}

variable "sku_name" {
  type = string
}

variable "storage_mb" {
  type = number
}

variable "delegated_subnet_id" {
  type = string
}

variable "private_dns_zone_id" {
  description = "privatelink.postgres.database.azure.com zone id."
  type        = string
}

variable "tenant_id" {
  type = string
}

variable "cmk_identity_id" {
  type = string
}

variable "cmk_versionless_key_id" {
  type = string
}

variable "geo_cmk_identity_id" {
  type    = string
  default = null
}

variable "geo_cmk_versionless_key_id" {
  type    = string
  default = null
}

variable "tier" {
  type = string
}

variable "backup_policy" {
  type = object({
    pitr_retention_days = number
    geo_redundant       = bool
  })
}

variable "dba_group_object_id" {
  type = string
}

variable "dba_group_name" {
  type = string
}

variable "pipeline_l3_object_id" {
  type = string
}

variable "pipeline_l3_name" {
  type = string
}

variable "log_analytics_workspace_id" {
  type = string
}

variable "allowed_extensions" {
  description = "Union of extensions requested by every database on this server (spec section 10.2.7); L2 computes this from the YAML requests."
  type        = list(string)
  default     = []
}

variable "extra_parameters" {
  type    = map(string)
  default = {}
}

variable "allowed_classifications" {
  type = list(string)
}

variable "max_databases_per_server" {
  type    = number
  default = 20
}

variable "reserved_connections" {
  type    = number
  default = 10
}

variable "tags" {
  type    = map(string)
  default = {}
}
