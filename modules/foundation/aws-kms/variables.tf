variable "name_prefix" {
  type = string
}

variable "purposes" {
  description = "One CMK per purpose, per spec section 8.1: rds, dynamodb, secrets, backup, logs, tfstate."
  type        = list(string)
  default     = ["rds", "dynamodb", "secrets", "backup", "logs", "tfstate"]
}

variable "key_admin_arns" {
  description = "Principals who may manage key policy/lifecycle but NOT use the key for crypto operations."
  type        = list(string)
}

variable "key_user_arns" {
  description = "Map of purpose => list of principal ARNs allowed to use that purpose's key for Encrypt/Decrypt/GenerateDataKey."
  type        = map(list(string))
}

variable "break_glass_arns" {
  description = "Principals allowed kms:ScheduleKeyDeletion. Empty by default — deletion is break-glass only."
  type        = list(string)
  default     = []
}

variable "multi_region" {
  description = "Purposes that need a multi-region primary key (for cross-region backup copy)."
  type        = list(string)
  default     = []
}

variable "tags" {
  type    = map(string)
  default = {}
}
