variable "name" {
  type = string
}

variable "resource_group_name" {
  type = string
}

variable "location" {
  type = string
}

variable "delegated_subnet_id" {
  type = string
}

variable "sku_name" {
  type    = string
  default = "GP_Gen5"
}

variable "vcores" {
  type    = number
  default = 4
}

variable "storage_size_gb" {
  type    = number
  default = 256
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

variable "tier" {
  type = string
}

variable "tags" {
  type    = map(string)
  default = {}
}
