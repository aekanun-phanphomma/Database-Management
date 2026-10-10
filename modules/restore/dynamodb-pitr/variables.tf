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

variable "billing_mode" {
  type    = string
  default = "PAY_PER_REQUEST"
}

variable "hash_key" {
  description = "Must match the source table's key schema exactly — the provider does not infer it from restore_source_name."
  type        = string
}

variable "range_key" {
  type    = string
  default = null
}

variable "attributes" {
  description = "Must match the source table's attribute definitions exactly (same reason as hash_key/range_key)."
  type        = map(string)
}

variable "global_secondary_indexes" {
  type = list(object({
    name            = string
    hash_key        = string
    range_key       = optional(string)
    projection_type = string
  }))
  default = []
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
