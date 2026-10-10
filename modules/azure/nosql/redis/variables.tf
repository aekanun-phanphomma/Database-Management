variable "name" {
  type = string
}

variable "resource_group_name" {
  type = string
}

variable "location" {
  type = string
}

variable "sku_name" {
  type    = string
  default = "Premium"
}

variable "family" {
  type    = string
  default = "P"
}

variable "capacity" {
  type    = number
  default = 1
}

variable "private_endpoint_subnet_id" {
  type = string
}

variable "private_dns_zone_id" {
  description = "privatelink.redis.cache.windows.net zone id."
  type        = string
}

variable "tier" {
  type = string
}

variable "tags" {
  type    = map(string)
  default = {}
}
