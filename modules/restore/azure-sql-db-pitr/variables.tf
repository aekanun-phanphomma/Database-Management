variable "source_database_id" {
  type = string
}

variable "restore_tag" {
  type = string
}

variable "restore_point_in_time" {
  type = string
}

variable "target_server_id" {
  description = "Usually the same server as the source — per-database PITR restores onto any server you specify, including the same one (spec section 13.3: Azure SQL DB has native per-database PITR, unlike Postgres/MySQL)."
  type        = string
}

variable "sku_name" {
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
