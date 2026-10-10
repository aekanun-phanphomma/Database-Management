variable "name_prefix" {
  type = string
}

variable "resource_group_name" {
  type = string
}

variable "location" {
  type = string
}

variable "vnet_id" {
  description = "Existing hub-spoke DB VNet. This module does not create the VNet."
  type        = string
}

variable "vnet_name" {
  type = string
}

variable "delegated_subnets" {
  description = "Map of subnet name => { address_prefix, delegation_service_name }."
  type = map(object({
    address_prefix          = string
    delegation_service_name = string
  }))
}

variable "private_endpoint_subnet" {
  type = object({
    name           = string
    address_prefix = string
  })
}

variable "private_dns_zone_names" {
  description = "Zones per spec section 8.2, linked centrally from the connectivity subscription."
  type = list(string)
  default = [
    "privatelink.postgres.database.azure.com",
    "privatelink.database.windows.net",
    "privatelink.documents.azure.com",
    "privatelink.mongo.cosmos.azure.com",
    "privatelink.redis.cache.windows.net",
    "privatelink.vaultcore.azure.net",
    "privatelink.blob.core.windows.net",
  ]
}

variable "hub_vnet_id" {
  description = "Hub VNet to also link each private DNS zone to."
  type        = string
}

variable "tags" {
  type    = map(string)
  default = {}
}
