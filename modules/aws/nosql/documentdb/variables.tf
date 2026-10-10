variable "name" {
  type = string
}

variable "engine_version" {
  type    = string
  default = "5.0" # TODO(verify): confirm latest supported DocumentDB version at implementation time
}

variable "instance_class" {
  type = string
}

variable "instance_count" {
  type    = number
  default = 1
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

variable "tags" {
  type    = map(string)
  default = {}
}
