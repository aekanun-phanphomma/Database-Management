variable "name" {
  type = string
}

variable "resource_group_name" {
  type = string
}

variable "location" {
  type = string
}

variable "mysql_version" {
  type    = string
  default = "8.0.21"
}

variable "sku_name" {
  type = string
}

variable "storage_gb" {
  type = number
}

variable "delegated_subnet_id" {
  type = string
}

variable "private_dns_zone_id" {
  type = string
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

variable "tier" {
  type = string
}

variable "backup_policy" {
  type = object({
    pitr_retention_days = number
    geo_redundant       = bool
  })
}

variable "log_analytics_workspace_id" {
  type = string
}

variable "tags" {
  type    = map(string)
  default = {}
}
