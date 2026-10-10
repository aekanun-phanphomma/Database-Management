variable "source_account_name" {
  type = string
}

variable "source_account_id" {
  type = string
}

variable "restore_tag" {
  type = string
}

variable "restore_time_utc" {
  type = string
}

variable "resource_group_name" {
  type = string
}

variable "location" {
  type = string
}

variable "databases_to_restore" {
  description = "List of database names to restore; empty = whole account."
  type        = list(string)
  default     = []
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
