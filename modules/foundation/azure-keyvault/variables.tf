variable "name_prefix" {
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

variable "private_endpoint_subnet_id" {
  type = string
}

variable "private_dns_zone_id" {
  description = "id of privatelink.vaultcore.azure.net, from azure-network-db."
  type        = string
}

variable "purposes" {
  description = "One CMK per purpose, mirroring aws-kms: postgres, mssql, mysql, cosmos, backup, logs, tfstate."
  type        = list(string)
  default     = ["postgres", "mssql", "mysql", "cosmos", "backup", "logs", "tfstate"]
}

variable "admin_object_ids" {
  description = "Principals granted Key Vault Administrator (RBAC)."
  type        = list(string)
}

variable "tags" {
  type    = map(string)
  default = {}
}
