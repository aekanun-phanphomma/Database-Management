variable "name" {
  type = string
}

variable "resource_group_name" {
  type = string
}

variable "location" {
  type = string
}

variable "private_endpoint_subnet_id" {
  type = string
}

variable "private_dns_zone_id" {
  description = "privatelink.mongo.cosmos.azure.com zone id."
  type        = string
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
