variable "name" {
  type = string
}

variable "engine_version" {
  type    = string
  default = "8.0" # TODO(verify): confirm latest supported RDS MySQL version at implementation time
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
