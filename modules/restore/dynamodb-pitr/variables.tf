variable "source_table_name" {
  type = string
}

variable "restore_tag" {
  type = string
}

variable "restore_time_utc" {
  description = "RFC3339 UTC timestamp. null = restore to latest (DynamoDB native PITR supports this directly, unlike RDS)."
  type        = string
  default     = null
}

variable "kms_key_arn" {
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
