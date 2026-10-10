variable "name_prefix" {
  description = "e.g. acme-prod"
  type        = string
}

variable "vpc_id" {
  description = "Existing VPC to place DB subnets in. This module does not create the VPC itself."
  type        = string
}

variable "vpc_cidr" {
  type = string
}

variable "availability_zones" {
  description = "At least 3 AZs for the DB subnet group."
  type        = list(string)
  validation {
    condition     = length(var.availability_zones) >= 3
    error_message = "At least 3 availability zones are required for a DB subnet group."
  }
}

variable "private_subnet_cidrs" {
  description = "One CIDR per AZ, sized to allow restore instances alongside prod (spec section 8.1)."
  type        = list(string)
  validation {
    condition     = length(var.private_subnet_cidrs) == length(var.availability_zones)
    error_message = "private_subnet_cidrs must have exactly one entry per availability_zones entry."
  }
}

variable "private_route_table_ids" {
  description = "Route tables with no IGW route, associated to the new DB subnets."
  type        = list(string)
}

variable "app_security_group_ids" {
  description = "Security groups allowed to initiate connections to DB servers on the engine port."
  type        = list(string)
  default     = []
}

variable "runner_cidr_blocks" {
  description = "CIDR(s) of the CI runner subnet, allowed to reach VPC endpoints."
  type        = list(string)
}

variable "private_dns_zone_name" {
  description = "e.g. db.prod.internal"
  type        = string
}

variable "interface_endpoint_services" {
  description = "AWS service names for interface VPC endpoints, without the com.amazonaws.<region>. prefix."
  type        = list(string)
  default     = ["secretsmanager", "kms", "logs", "sts", "ssm", "ssmmessages", "rds"]
}

variable "tags" {
  type    = map(string)
  default = {}
}
