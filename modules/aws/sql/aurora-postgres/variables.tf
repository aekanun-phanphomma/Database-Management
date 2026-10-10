variable "name" {
  type = string
}

variable "engine_version" {
  type    = string
  default = "16.4" # TODO(verify): confirm latest supported Aurora PostgreSQL version at implementation time
}

variable "instance_class" {
  type = string
}

variable "instance_count" {
  description = "Writer + readers. 2 for tier1 (HA), 1 for tier2/3."
  type        = number
  default     = 1
}

variable "db_subnet_group_name" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "ingress_security_group_ids" {
  type = list(string)
}

variable "kms_key_arn" {
  type = string
}

variable "secrets_kms_key_arn" {
  type = string
}

variable "tier" {
  type = string
}

variable "backup_policy" {
  type = object({
    pitr_retention_days = number
  })
}

variable "alarm_topic_arn" {
  type = string
}

variable "allowed_classifications" {
  type = list(string)
}

variable "max_connections_override" {
  type    = number
  default = null
}

variable "reserved_connections" {
  type    = number
  default = 10
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

variable "tags" {
  type    = map(string)
  default = {}
}
