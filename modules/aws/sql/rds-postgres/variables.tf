variable "name" {
  description = "RDS identifier, e.g. acme-prod-pg-shared01"
  type        = string
}

variable "engine_version" {
  type    = string
  default = "16.4" # TODO(verify): confirm latest supported RDS Postgres version at implementation time
}

variable "instance_class" {
  type = string
}

variable "allocated_storage" {
  type = number
}

variable "max_allocated_storage" {
  type = number
}

variable "db_subnet_group_name" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "ingress_security_group_ids" {
  description = "App + runner SGs allowed to reach port 5432 (spec section 8.1: one SG per server)."
  type        = list(string)
}

variable "kms_key_arn" {
  type = string
}

variable "secrets_kms_key_arn" {
  type = string
}

variable "tier" {
  description = "tier1 | tier2 | tier3 — drives multi_az and backup_retention_period."
  type        = string
}

variable "backup_policy" {
  description = "Looked up from modules/_shared/backup-policy by tier."
  type = object({
    pitr_retention_days = number
  })
}

variable "enhanced_monitoring_role_arn" {
  type = string
}

variable "alarm_topic_arn" {
  type = string
}

variable "allowed_classifications" {
  description = "Which data_classification values this server accepts (spec section 10.1 / ADR 0004)."
  type        = list(string)
}

variable "max_connections_override" {
  description = "null = engine default formula via parameter group; set to override."
  type        = number
  default     = null
}

variable "reserved_connections" {
  description = "Connections reserved for admin/superuser use, subtracted from the budget L2 enforces."
  type        = number
  default     = 10
}

variable "max_databases_per_server" {
  type    = number
  default = 20
}

variable "private_dns_zone_id" {
  type = string
}

variable "private_dns_zone_name" {
  type = string
}

variable "dba_admin_iam_arns" {
  description = "IAM principals mapped to rds_iam DB role for admin access (bound at L3, listed here only for reference/tagging)."
  type        = list(string)
  default     = []
}

variable "tags" {
  type    = map(string)
  default = {}
}
