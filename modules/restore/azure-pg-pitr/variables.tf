variable "source_server_id" {
  type = string
}

variable "restore_tag" {
  type = string
}

variable "restore_time_utc" {
  description = "RFC3339 UTC timestamp. Required — Azure Flexible Server PITR has no 'latest' shortcut like RDS."
  type        = string
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

variable "private_dns_zone_id" {
  type = string
}

variable "ticket" {
  type = string
}

variable "ttl_at_utc" {
  type = string
}

variable "requested_by" {
  type = string
}

variable "tags" {
  type    = map(string)
  default = {}
}
