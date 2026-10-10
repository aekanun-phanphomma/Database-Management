variable "source_identifier" {
  description = "Identifier of the server/cluster being restored (spec section 13.5)."
  type        = string
}

variable "source_is_cluster" {
  description = "true for Aurora, false for single-instance RDS."
  type        = bool
  default     = false
}

variable "restore_time_utc" {
  description = "RFC3339 UTC timestamp to restore to. null = restore to latest restorable time."
  type        = string
  default     = null
}

variable "restore_tag" {
  description = "Short unique suffix for the restored resource's identifier, e.g. the restore ticket number."
  type        = string
}

variable "instance_class" {
  type = string
}

variable "db_subnet_group_name" {
  type = string
}

variable "restore_security_group_ids" {
  type = list(string)
}

variable "kms_key_arn" {
  type = string
}

variable "ticket" {
  type = string
}

variable "ttl_at_utc" {
  description = "Absolute RFC3339 expiry timestamp, computed once by the CI pipeline from restore_time_utc + ttl_hours when the restore PR is opened. Deliberately NOT computed in Terraform with timestamp(), which would drift every plan."
  type        = string
}

variable "requested_by" {
  type = string
}

variable "tags" {
  type    = map(string)
  default = {}
}
