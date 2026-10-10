variable "name" {
  type = string
}

variable "resource_group_name" {
  type = string
}

variable "location" {
  type = string
}

variable "tenant_id" {
  type = string
}

variable "dba_group_object_id" {
  type = string
}

variable "dba_group_name" {
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
  description = "privatelink.database.windows.net zone id."
  type        = string
}

variable "log_analytics_workspace_id" {
  type = string
}

variable "elastic_pool" {
  description = "null = no pool (each database gets its own DTU/vCore allocation); set to pool databases together."
  type = object({
    sku_name  = string
    max_size_gb = number
  })
  default = null
}

variable "tags" {
  type    = map(string)
  default = {}
}
